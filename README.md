# PHP2Shell: Disable PHP Session Upload Progress

A Bash snippet for packaged and custom-built PHP installations. Finds the loaded config using `php --ini`, includes existing Debian/Ubuntu Apache and CLI configs for that PHP version, backs up all selected files, and sets `session.upload_progress.enabled = 0`.

## Why?

PHP's [23 October 2026 advisory](https://www.php.net/archive/2026.php#2026-10-23-1) recommends disabling session upload progress until the next regular bugfix release to protect against an additional, configuration-dependent RCE vector (CVE-2026-115560).

The related [21 October security announcement](https://www.php.net/archive/2026.php) covers two critical remote code execution vulnerabilities discussed as PHP2Shell:

- **CVE-2026-109618:** RCE via out-of-memory corruption.
- **CVE-2026-109619:** RCE via stale global state.

**This configuration change is a mitigation, not a complete fix for those two vulnerabilities.** It blocks confirmed session attack paths for CVE-2026-109619; it does not fix CVE-2026-109618 or every variant of CVE-2026-109619. Update to PHP 8.2.35, 8.3.36, 8.4.27, 8.5.12, or a later patched release, or obtain vendor backports. PHP 7.4 requires vendor fixes, source backports, or an upgrade.

## Apply

Requires Bash, sudo, GNU/Linux utilities, and PHP on your PATH. Supports custom paths such as `/opt/php83/etc/php.ini`. Restarting Apache briefly interrupts service.

```bash
sudo bash -s -- "$(command -v php)" <<'BASH'
set -euo pipefail
php_bin="$1"
v=$("$php_bin" -r 'echo PHP_MAJOR_VERSION.".".PHP_MINOR_VERSION;')
loaded=$(LC_ALL=C "$php_bin" --ini | sed -n 's/^Loaded Configuration File:[[:space:]]*//p')
if [[ -z "$loaded" || "$loaded" == '(none)' || ! -f "$loaded" ]]; then
    echo '[ERROR] PHP has no existing loaded php.ini' >&2
    exit 1
fi
stamp=$(date +%Y%m%d-%H%M%S).$$
files=()
declare -A seen=()
for candidate in "$loaded" /etc/php/"$v"/{apache2,cli}/php.ini; do
    [[ -f "$candidate" ]] || continue
    file=$(readlink -f -- "$candidate")
    [[ -z "${seen[$file]:-}" ]] || continue
    seen["$file"]=1
    files+=("$file")
done

# Back up ALL selected files before editing any of them.
for file in "${files[@]}"; do
    cp -a -- "$file" "$file.bak.$stamp"
    echo "[BACKUP] $file.bak.$stamp"
done

for file in "${files[@]}"; do
    if grep -Eq '^[[:space:]]*;?[[:space:]]*session\.upload_progress\.enabled[[:space:]]*=' "$file"; then
        sed -Ei 's/^[[:space:]]*;?[[:space:]]*session\.upload_progress\.enabled[[:space:]]*=.*/session.upload_progress.enabled = 0/' "$file"
    else
        printf '\nsession.upload_progress.enabled = 0\n' >> "$file"
    fi
    echo "[OK] Updated $file"
done

if command -v systemctl >/dev/null && systemctl is-active --quiet apache2; then
    systemctl restart apache2
    echo '[OK] Apache restarted'
fi

"$php_bin" -r 'echo "session.upload_progress.enabled=", ini_get("session.upload_progress.enabled") ? "1 (enabled)" : "0 (disabled)", PHP_EOL;'
BASH
```

The script preserves the PHP executable selected by your shell, skips missing standard paths, and avoids editing the same resolved file twice. It stops on failure. It handles commented settings and adds the directive when absent. Backups remain beside each original file with a timestamp and process ID suffix.

## Verify CLI

```bash
php -r 'echo "session.upload_progress.enabled=", ini_get("session.upload_progress.enabled") ? "1 (enabled)" : "0 (disabled)", PHP_EOL;'
```

Expected: `session.upload_progress.enabled=0 (disabled)`.

## Verify the website

CLI and web PHP can load different configurations. Temporarily place this in a PHP file on the website and open it in your browser:

```php
<?php
header('Content-Type: text/plain');
header('Cache-Control: no-store');
echo 'PHP: ', PHP_VERSION, "\n";
echo 'Handler: ', PHP_SAPI, "\n";
echo 'Config: ', php_ini_loaded_file() ?: '(none)', "\n";
echo 'Upload progress: ', ini_get('session.upload_progress.enabled') ? 'enabled' : 'disabled', "\n";
```

Confirm `Upload progress: disabled`, then delete the temporary file.

## Scope

- Detects the default `php` version, which may differ from the website's version.
- Updates the loaded CLI config plus existing `/etc/php/VERSION/apache2/php.ini` and `cli/php.ini`. `php --ini` describes CLI only; it cannot discover a separate Apache or FPM config in a custom installation.
- Restarts Apache only when the `apache2` systemd service is active. For custom web services or PHP-FPM, locate the web config using the browser check above, apply the same setting there, and restart every relevant worker using your service manager.
- Additional `.ini` files or server settings can override `php.ini`; verify the effective website setting.
- Do not rely on application `ini_set()` or FPM `.user.ini` for this mitigation: the setting must apply before request parsing.
- Disables PHP's session-based upload progress tracking. Applications using that feature lose those progress updates.

## Restore

Use the exact backup suffix printed by the script:

```bash
sudo cp -a /etc/php/7.4/apache2/php.ini.bak.YOUR-SUFFIX /etc/php/7.4/apache2/php.ini
sudo cp -a /etc/php/7.4/cli/php.ini.bak.YOUR-SUFFIX /etc/php/7.4/cli/php.ini
sudo systemctl restart apache2
```

Replace `7.4` with your PHP version. For a custom build, restore the printed backup to its original path, such as `/opt/php83/etc/php.ini`, and restart the relevant web service. Restoring may re-enable upload progress; reassess the advisory before reverting.
