# PHP2Shell: Disable PHP Session Upload Progress

A small Bash snippet for Debian/Ubuntu PHP installations. Detects the default CLI PHP major/minor version, backs up its Apache and CLI `php.ini` files, and sets `session.upload_progress.enabled = 0`.

## Why?

PHP's [23 October 2026 advisory](https://www.php.net/archive/2026.php#2026-10-23-1) recommends disabling session upload progress until the next regular bugfix release to protect against an additional, configuration-dependent RCE vector (CVE-2026-115560).

The related [21 October security announcement](https://www.php.net/archive/2026.php) covers two critical remote code execution vulnerabilities discussed as PHP2Shell:

- **CVE-2026-109618:** RCE via out-of-memory corruption.
- **CVE-2026-109619:** RCE via stale global state.

**This configuration change is a mitigation, not a complete fix for those two vulnerabilities.** It blocks confirmed session attack paths for CVE-2026-109619; it does not fix CVE-2026-109618 or every variant of CVE-2026-109619. Update to PHP 8.2.35, 8.3.36, 8.4.27, 8.5.12, or a later patched release, or obtain vendor backports. PHP 7.4 requires vendor fixes, source backports, or an upgrade.

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
- Updates Apache module and CLI configs only. PHP-FPM requires its own config change and a restart of every relevant FPM worker.
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

Replace `7.4` with your PHP version. Restoring may re-enable upload progress; reassess the advisory before reverting.
