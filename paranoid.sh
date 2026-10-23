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
BASH
