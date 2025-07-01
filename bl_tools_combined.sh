#!/bin/bash
# BL Site Management Tools - Self-Extracting Archive
# Version: 1.2.3
# Last Updated: 2025-07-01
# Usage: ./bl_tools_combined.sh [extract_directory]
#
# This script contains all BL tools in one file.
# Run with directory argument to extract and install to specified directory.

# Default extraction directory
EXTRACT_DIR="."
INSTALL_MODE=false

# Check arguments
if [[ $# -eq 1 ]]; then
    # One argument - install to specified directory
    EXTRACT_DIR="$1"
    INSTALL_MODE=true
else
    echo "Usage: $0 [install_directory]"
    echo "  install_directory: Extract and install to specified directory"
    exit 1
fi

if [[ "$INSTALL_MODE" == "true" ]]; then
    echo "Installing BL Site Management Tools v1.2.1 to: $EXTRACT_DIR"
    
    # Create target directory if it doesn't exist
    if [[ ! -d "$EXTRACT_DIR" ]]; then
        mkdir -p "$EXTRACT_DIR" || {
            echo "Error: Cannot create directory $EXTRACT_DIR"
            exit 1
        }
    fi
    
    # Check if we can write to the directory
    if [[ ! -w "$EXTRACT_DIR" ]]; then
        echo "Error: Cannot write to directory $EXTRACT_DIR"
        echo "Try: sudo $0 $EXTRACT_DIR"
        exit 1
    fi
else
    echo "Something went wrong."
	exit 1
fi

# Find where the file separator data starts
SCRIPT_PATH="$0"

# Extract everything after the first FILE_SEPARATOR and process it
sed -n '/^#=== FILE_SEPARATOR ===/,$p' "$SCRIPT_PATH" | awk -v extract_dir="$EXTRACT_DIR" 'BEGIN { 
    file_count = 0
    in_file = 0
    filename = ""
}
/^#=== FILE_SEPARATOR ===/ {
    if (in_file && filename != "") {
        close(full_filename)
        print "Created: " full_filename
    }
    getline
    if ($0 ~ /^# File: /) {
        filename = $3
        if (extract_dir != ".") {
            full_filename = extract_dir "/" filename
        } else {
            full_filename = filename
        }
        in_file = 1
        file_count++
    }
    next
}
in_file && filename != "" {
    print $0 > full_filename
}
END {
    if (in_file && filename != "") {
        close(full_filename)
        print "Created: " full_filename
    }
    print ""
    print "Extraction complete! Created " file_count " files."
}'

# Set appropriate permissions for extracted files
echo "Setting file permissions..."
for file in "$EXTRACT_DIR"/bl_* "$EXTRACT_DIR"/README.md; do
    if [[ -f "$file" ]]; then
        if [[ "$file" == *"README.md" ]]; then
            chmod 644 "$file"  # Make README readable, not executable
            echo "Created documentation: $file"
        else
            chmod +x "$file"   # Make tools executable
            echo "Made executable: $file"
        fi
    fi
done

echo ""
echo "Installation complete!"
echo "Tools installed to: $EXTRACT_DIR"
echo ""
echo "Version: 1.2.1"
echo "Total tools: 21 (plus bl_common.sh and README.md)"
echo ""
echo "IMPORTANT: Review and adjust the configuration in:"
echo "  $EXTRACT_DIR/bl_common.sh"
echo ""
echo "Key settings to verify:"
echo "  - BL_USER (currently set to 'nsp')"
echo "  - MANAGEMENT_STATION_IP (currently set to '1.1.1.1')"
echo ""
echo "Documentation available at: $EXTRACT_DIR/README.md"
echo ""
echo "To use the tools, either:"
echo "  1. Add $EXTRACT_DIR to your PATH"
echo "  2. Create symlinks: ln -s $EXTRACT_DIR/bl_* /usr/local/bin/"
echo "  3. Run tools directly: $EXTRACT_DIR/bl_site_list"

exit 0

exit 0

#=== FILE_SEPARATOR ===
# File: bl_common.sh
#!/bin/bash
# bl_common.sh - Common configuration and functions for BL tools
# Version: 1.2.1
# This file should be sourced by all BL tools

# Configuration Variables
BL_USER="nsp"
MANAGEMENT_STATION_IP="1.1.1.1"
BL_TOOLS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BL_DATA_FILE="${BL_TOOLS_DIR}/bl_site.data"
BL_CONFIG_FILE_PATH="/in/conf/local.override.config.php"

# Data file header (if file doesn't exist)
BL_DATA_HEADER="short_name|type|status|fs_base_path|url_base|notes|created|last_updated|inactivated"

# Enum values
VALID_TYPES=("prod" "stage" "qa" "dev")
VALID_STATUSES=("ok" "disabled" "error")

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Check if running as correct user
check_user() {
    if [[ $USER != "$BL_USER" ]]; then
        echo -e "${RED}Error: This tool must be run as user '$BL_USER'${NC}" >&2
        exit 1
    fi
}

# Initialize data file if it doesn't exist
init_data_file() {
    if [[ ! -f "$BL_DATA_FILE" ]]; then
        echo "$BL_DATA_HEADER" > "$BL_DATA_FILE"
        echo -e "${GREEN}Created data file: $BL_DATA_FILE${NC}"
    fi
}

# Validate type enum
validate_type() {
    local type="$1"
    for valid_type in "${VALID_TYPES[@]}"; do
        if [[ "$type" == "$valid_type" ]]; then
            return 0
        fi
    done
    return 1
}

# Validate status enum
validate_status() {
    local status="$1"
    for valid_status in "${VALID_STATUSES[@]}"; do
        if [[ "$status" == "$valid_status" ]]; then
            return 0
        fi
    done
    return 1
}

# Get current timestamp
get_timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# Check if site exists and is active
site_exists() {
    local short_name="$1"
    if [[ -f "$BL_DATA_FILE" ]]; then
        # Check if site exists and is not inactivated (inactivated field is empty)
        grep -q "^${short_name}|.*||$" "$BL_DATA_FILE" || grep -q "^${short_name}|.*|$" "$BL_DATA_FILE"
    else
        return 1
    fi
}

# Get site data (only active sites)
get_site_data() {
    local short_name="$1"
    if [[ -f "$BL_DATA_FILE" ]]; then
        # Get site data only if not inactivated (inactivated field is empty)
        grep "^${short_name}|" "$BL_DATA_FILE" | grep -E "\|\|$|\|$"
    fi
}

# Get all active sites
get_active_sites() {
    if [[ -f "$BL_DATA_FILE" ]]; then
        # Skip header and get only active sites (inactivated field is empty)
        tail -n +2 "$BL_DATA_FILE" | grep -E "\|\|$|\|$"
    fi
}

# Get fs_base_path for a site (only if active)
get_site_fs_base() {
    local short_name="$1"
    local site_data=$(get_site_data "$short_name")
    if [[ -n "$site_data" ]]; then
        echo "$site_data" | cut -d'|' -f4
    fi
}

# Print error message
error_msg() {
    echo -e "${RED}Error: $1${NC}" >&2
}

# Print success message
success_msg() {
    echo -e "${GREEN}$1${NC}"
}

# Print warning message
warning_msg() {
    echo -e "${YELLOW}Warning: $1${NC}"
}

# Print info message
info_msg() {
    echo -e "${CYAN}$1${NC}"
}

# Edit PHP config file - preserves layout and comments
edit_php_config() {
    local config_file="$1"
    local key="$2"
    local value="$3"
    
    if [[ ! -f "$config_file" ]]; then
        error_msg "Config file not found: $config_file"
        return 1
    fi
    
    # Create backup
    cp "$config_file" "${config_file}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Create temporary PHP script
    local temp_script=$(mktemp)
    cat > "$temp_script" << 'PHPEOF'
<?php
$config_file = $argv[1];
$key = $argv[2];
$value_str = $argv[3];

// Read the original file content
$content = file_get_contents($config_file);
if ($content === false) {
    exit(1);
}

// Parse the key path
$keys = explode('.', $key);
$target_key = end($keys);

// Convert value string to proper PHP value
$value = json_decode($value_str, true);
if ($value === null && $value_str !== 'null') {
    // If it's not valid JSON, treat as string/number
    if (is_numeric($value_str)) {
        $value = (int)$value_str;
    } else {
        $value = $value_str;
    }
}

// Create the new value string - strip any newlines
$new_value = str_replace("\n",'',var_export($value, true));

// Escape the target key for regex
$escaped_key = preg_quote($target_key, '/');

// Split content into lines for easier processing
$lines = explode("\n", $content);
$modified = false;

for ($i = 0; $i < count($lines); $i++) {
    $line = $lines[$i];
    
    // Check if this line contains our target key
    // Handle both 'key' => and ,'key' => formats
    if (preg_match("/^(\s*,?\s*['\"]${escaped_key}['\"]\\s*=>\\s*)/", $line, $matches)) {
        // Found the line with our key
        $prefix = $matches[1];
        $after_arrow = substr($line, strlen($matches[0]));
        
        // Now we need to find where the value ends
        // Look for a comma or comment that's not inside a string or array
        $in_string = false;
        $string_char = '';
        $array_depth = 0;
        $value_end = strlen($after_arrow);
        $found_end = false;
        
        for ($j = 0; $j < strlen($after_arrow); $j++) {
            $char = $after_arrow[$j];
            $next_char = ($j + 1 < strlen($after_arrow)) ? $after_arrow[$j + 1] : '';
            
            // Handle string state
            if (!$in_string && ($char === '"' || $char === "'")) {
                $in_string = true;
                $string_char = $char;
            } elseif ($in_string && $char === $string_char && ($j === 0 || $after_arrow[$j-1] !== '\\')) {
                $in_string = false;
            }
            
            // Handle array depth
            if (!$in_string) {
                if ($char === '[') $array_depth++;
                if ($char === ']') $array_depth--;
                
                // Check for end of value
                if ($array_depth === 0) {
                    // Skip any spaces after the value to find the real delimiter
                    if (!$found_end && ($char === ' ' || $char === "\t")) {
                        // Skip whitespace
                        continue;
                    }
                    
                    if ($char === ',') {
                        // Found comma - include any spaces before it in the value
                        $k = $j;
                        while ($k > 0 && ($after_arrow[$k-1] === ' ' || $after_arrow[$k-1] === "\t")) {
                            $k--;
                        }
                        $value_end = $k;
                        $found_end = true;
                        break;
                    }
                    if ($char === '/' && $next_char === '/') {
                        // Found comment - include any spaces before it in the value
                        $k = $j;
                        while ($k > 0 && ($after_arrow[$k-1] === ' ' || $after_arrow[$k-1] === "\t")) {
                            $k--;
                        }
                        $value_end = $k;
                        $found_end = true;
                        break;
                    }
                }
            }
        }
        
        // If we didn't find a delimiter, trim trailing whitespace
        if (!$found_end) {
            $value_end = strlen(rtrim($after_arrow));
        }
        
        // Extract the old value (to preserve any spacing)
        $old_value = substr($after_arrow, 0, $value_end);
        $old_value_trimmed = rtrim($old_value);
        
        // Get spacing that was after the old value
        $spacing = substr($old_value, strlen($old_value_trimmed));
        
        // Extract the suffix (everything after the value)
        $suffix = substr($after_arrow, $value_end);
        
        // Build the new line - add spacing back if there was any
        $lines[$i] = $prefix . $new_value . $spacing . $suffix;
        $modified = true;
        break;
    }
}

if ($modified) {
    file_put_contents($config_file, implode("\n", $lines));
    exit(0);
} else {
    exit(2);
}
PHPEOF
    
    # Run the PHP script
    php "$temp_script" "$config_file" "$key" "$value"
    local php_result=$?
    
    # Clean up temp script
    rm -f "$temp_script"
    
    case $php_result in
        0)
            return 0  # Success
            ;;
        2)
            error_msg "Configuration key '$key' not found in file"
            return 1
            ;;
        *)
            error_msg "Failed to update configuration file"
            return 1
            ;;
    esac
}

#=== FILE_SEPARATOR ===
# File: README.md
# BL Site Management Tools - Comprehensive Documentation

## Overview

The BL Site Management Tools is a comprehensive command-line toolkit for managing multiple websites and code components on Ubuntu Linux. All tools use the `bl_` prefix and are designed to run as a specific user with centralized configuration management.

**Version**: 1.2.1  
**Total Tools**: 21 (plus bl_common.sh for shared functions)

**Tools included**:
- Database management: `bl_db_add`, `bl_db_update`, `bl_db_inactivate`, `bl_db_backup`, `bl_db_restore`
- Site queries: `bl_site_list`, `bl_site_show`, `bl_site_quicklist`, `bl_site_config_delete_backups`
- Git operations: `bl_git_status`, `bl_git_pull`, `bl_git_checkout`, `bl_git_prune`, `bl_git_branch_cleanup`
- Site control: `bl_disable_site`, `bl_enable_site`, `bl_limit_site`, `bl_unlimit_site`
- Configuration: `bl_config_get`, `bl_config_set`
- System tools: `bl_health_check`

## Installation

### Quick Installation
```bash
# Make the combined script executable and extract
chmod +x bl_tools_combined.sh
./bl_tools_combined.sh

# Or install to specific directory
sudo ./bl_tools_combined.sh /opt/bl_tools
```

### Configuration
After installation, review and adjust the configuration in `bl_common.sh`:

```bash
# Key settings to verify:
BL_USER="nsp"                    # User that must run the tools
MANAGEMENT_STATION_IP="1.1.1.1" # IP for site access restrictions
```

## Data Structure

Sites are stored in a human-readable pipe-delimited file (`bl_site.data`) with the following structure:

```
short_name|type|status|fs_base_path|url_base|notes|created|last_updated|inactivated
```

### Field Descriptions:
- **short_name**: Unique identifier (primary key)
- **type**: Environment type (prod, stage, qa, dev)
- **status**: Current status (ok, disabled, error)
- **fs_base_path**: Filesystem base directory
- **url_base**: Base URL for the site
- **notes**: Optional description/notes
- **created**: Creation timestamp
- **last_updated**: Last modification timestamp
- **inactivated**: Inactivation timestamp (empty = active)

## Tool Categories

### Database Tools (bl_db_*)
Tools that modify the site database records:

#### bl_db_add
Add a new site to the database.
```bash
bl_db_add <short_name> <type> <status> <fs_base_path> <url_base> [notes]

# Examples:
bl_db_add mysite prod ok /var/www/mysite https://mysite.com "Main production site"
bl_db_add testsite dev ok /var/www/test https://test.local
```

#### bl_db_update
Update existing site properties.
```bash
bl_db_update <short_name> [options]

# Options:
--type <type>           # Change environment type
--status <status>       # Change status
--fs-base-path <path>   # Change filesystem path
--url-base <url>        # Change base URL
--notes <notes>         # Change notes

# Examples:
bl_db_update mysite --status disabled
bl_db_update mysite --type stage --notes "Moved to staging"
```

#### bl_db_inactivate
Permanently inactivate a site (preserves data for history).
```bash
bl_db_inactivate <short_name>

# Example:
bl_db_inactivate oldsite
```

**Note**: Inactivated sites are preserved in the database but ignored by all other tools. This is permanent - sites cannot be reactivated.

#### bl_db_backup
Create timestamped backups of the site database.
```bash
bl_db_backup [backup_name]

# Examples:
bl_db_backup                    # Auto-timestamped backup
bl_db_backup before_migration   # Named backup
```

#### bl_db_restore
Restore database from a previous backup.
```bash
bl_db_restore <backup_name>

# Example:
bl_db_restore before_migration
```

### Query Tools (bl_site_*)
Tools that query and display site information:

#### bl_site_list
List and search sites with filtering and formatting options.
```bash
bl_site_list [options]

# Options:
--type <type>       # Filter by type (prod, stage, qa, dev)
--status <status>   # Filter by status (ok, disabled, error)
--search <term>     # Search in all fields
--sort <field>      # Sort by field number (1-8)
--format <format>   # Output format: table, csv, json

# Examples:
bl_site_list                           # Show all active sites
bl_site_list --type prod               # Show only production sites
bl_site_list --status ok --format csv  # Export healthy sites as CSV
bl_site_list --search "mysite"         # Search for sites containing "mysite"
```

#### bl_site_show
Display detailed information for a specific site.
```bash
bl_site_show <site_name>

# Example:
bl_site_show mysite
```

#### bl_site_quicklist
Simplified site listing showing only essential fields.
```bash
bl_site_quicklist [--format table|csv]

# Options:
--format table    # Table format (default)
--format csv      # CSV format

# Examples:
bl_site_quicklist                # Quick table view
bl_site_quicklist --format csv   # Export as CSV
```

Shows only: short_name, type, fs_base_path, and notes.

#### bl_site_config_delete_backups
Clean up configuration backup files for sites.
```bash
bl_site_config_delete_backups [site_name|--all] [--dry-run]

# Options:
--dry-run    # Show what would be deleted without actually deleting

# Examples:
bl_site_config_delete_backups mysite           # Delete backups for specific site
bl_site_config_delete_backups --all            # Delete backups for all active sites
bl_site_config_delete_backups --all --dry-run  # Preview what would be deleted
```

### Git Operations (bl_git_*)
Tools for Git repository management:

#### bl_git_status
Check Git status for sites.
```bash
bl_git_status [site_name|--all]

# Examples:
bl_git_status mysite    # Check specific site
bl_git_status --all     # Check all active sites
```

#### bl_git_pull
Pull Git updates for sites.
```bash
bl_git_pull [site_name|--all] [--force]

# Options:
--force    # Force pull even with dirty working directory

# Examples:
bl_git_pull mysite       # Pull specific site
bl_git_pull --all        # Pull all active sites
bl_git_pull --all --force # Force pull all sites
```

#### bl_git_checkout
Checkout a specific branch on sites.
```bash
bl_git_checkout <branch> <site_name|--all>

# Examples:
bl_git_checkout develop mysite    # Checkout develop branch on mysite
bl_git_checkout main --all        # Checkout main branch on all sites
bl_git_checkout feature/new-ui mysite  # Checkout feature branch
```

**Note**: This command will fail if there are uncommitted changes. Use `git stash` or commit changes before switching branches.

#### bl_git_prune
Prune deleted remote tracking branches.
```bash
bl_git_prune [site_name|--all]

# Examples:
bl_git_prune mysite    # Prune remote branches on mysite
bl_git_prune --all     # Prune remote branches on all sites
```

Runs `git fetch -a -p` to fetch all remotes and remove references to deleted remote branches.

#### bl_git_branch_cleanup
Clean up local branches whose remote tracking branch has been deleted.
```bash
bl_git_branch_cleanup [site_name|--all] [--delete-branches]

# Options:
--delete-branches    # Actually delete the branches (default: just list)

# Examples:
bl_git_branch_cleanup mysite                    # List branches with gone remotes
bl_git_branch_cleanup mysite --delete-branches  # Delete branches with gone remotes
bl_git_branch_cleanup --all                     # List on all sites
bl_git_branch_cleanup --all --delete-branches   # Delete on all sites
```

This tool helps clean up local branches that were tracking remote branches which have since been deleted (e.g., after PR merges).

### Site Control Tools (bl_*_site)
Tools for controlling site access and behavior:

#### bl_disable_site
Disable both staff and client access to sites.
```bash
bl_disable_site [site_name|--all]

# Examples:
bl_disable_site mysite    # Disable specific site
bl_disable_site --all     # Disable all active sites
```

#### bl_enable_site
Enable both staff and client access to sites.
```bash
bl_enable_site [site_name|--all]

# Examples:
bl_enable_site mysite     # Enable specific site
bl_enable_site --all      # Enable all active sites
```

#### bl_limit_site
Restrict site access to management station IP only.
```bash
bl_limit_site [site_name|--all]

# Examples:
bl_limit_site mysite      # Limit specific site
bl_limit_site --all       # Limit all active sites
```

#### bl_unlimit_site
Remove IP access restrictions from sites.
```bash
bl_unlimit_site [site_name|--all]

# Examples:
bl_unlimit_site mysite    # Remove limits from specific site
bl_unlimit_site --all     # Remove limits from all active sites
```

### Configuration Tools (bl_config_*)
Tools for managing PHP application configuration:

#### bl_config_get
Retrieve configuration values from site config files.
```bash
bl_config_get <site_name> <config_key>

# Examples:
bl_config_get mysite SITE.staff_open
bl_config_get mysite BS.version
```

#### bl_config_set
Set configuration values in site config files.
```bash
bl_config_set <site_name> <config_key> <value>

# Examples:
bl_config_set mysite SITE.staff_open 1
bl_config_set mysite SITE.limit_src_ip '["192.168.1.1","10.0.0.1"]'
```

Note: Array values must be valid JSON format with double quotes.

### System Tools
Maintenance and monitoring tools:

#### bl_health_check
Comprehensive system health check with optional auto-repair.
```bash
bl_health_check [--verbose] [--fix]

# Options:
--verbose    # Show detailed output for all checks
--fix        # Attempt to automatically fix common issues

# Examples:
bl_health_check                # Quick health check
bl_health_check --verbose      # Detailed health check
bl_health_check --verbose --fix # Detailed check with auto-repair
```

## PHP Configuration Management

The tools manage PHP configuration files located at `{fs_base_path}/in/conf/local.override.config.php`. The expected format is:

```php
<?php
$BS_CONF = [
    'BS' => [
        'name'       => 'SauBailShackle',
        'version'    => '1.6.2',
        'release'    => '2024-08-09'
    ],
    'SITE' => [
        'staff_open' => 1,         // Staff access (0=disabled, 1=enabled)
        'staff_limit_src' => 0,    // Staff IP limiting (0=off, 1=on)
        'client_open' => 1,        // Client access (0=disabled, 1=enabled)
        'client_limit_src' => 0,   // Client IP limiting (0=off, 1=on)
        'limit_src_ip' => ['192.168.1.1'], // Allowed IPs when limiting enabled
        'down_message' => 'Site temporarily down for maintenance',
        'block_src_ip' => []       // Always blocked IPs
    ]
];
```

## Common Workflows

### Adding a New Site
```bash
# 1. Add to database
bl_db_add newsite prod ok /var/www/newsite https://newsite.com "New production site"

# 2. Verify addition
bl_site_show newsite

# 3. Check if directory and git repo exist
bl_health_check --verbose

# 4. Pull latest code
bl_git_pull newsite
```

### Site Maintenance Mode
```bash
# Put site in maintenance (disable access)
bl_disable_site mysite

# Or limit to management IP only
bl_limit_site mysite

# Perform maintenance...

# Restore normal access
bl_enable_site mysite
bl_unlimit_site mysite
```

### Git Repository Maintenance
```bash
# Update and clean a specific site
bl_git_prune mysite                          # Prune deleted remote branches
bl_git_branch_cleanup mysite                 # List local branches with gone remotes
bl_git_branch_cleanup mysite --delete-branches  # Delete those branches

# Clean all sites at once
bl_git_prune --all                           # Prune all sites
bl_git_branch_cleanup --all                  # Check all sites
bl_git_branch_cleanup --all --delete-branches   # Clean all sites

# Full git maintenance workflow
bl_git_prune --all                           # First prune remotes
bl_git_branch_cleanup --all                  # Check what would be deleted
bl_git_branch_cleanup --all --delete-branches   # Clean up branches
bl_git_pull --all                            # Update all sites
```

### Maintenance and Cleanup
```bash
# Health check all sites
bl_health_check --verbose --fix

# Quick view of all sites
bl_site_quicklist

# Clean up config backup files
bl_site_config_delete_backups --all --dry-run  # Preview cleanup
bl_site_config_delete_backups --all            # Actually clean up

# Clean up specific site config backups
bl_site_config_delete_backups mysite
```

### Mass Operations
```bash
# Update all sites
bl_git_pull --all

# Checkout a specific branch on all sites
bl_git_checkout develop --all

# Prune remote branches on all sites
bl_git_prune --all

# Clean up local branches on all sites
bl_git_branch_cleanup --all --delete-branches

# Disable all sites for maintenance
bl_disable_site --all

# Check status of all sites
bl_git_status --all

# Health check with auto-fix
bl_health_check --verbose --fix
```

### Retiring a Site
```bash
# 1. Disable the site
bl_disable_site oldsite

# 2. Backup database before inactivation
bl_db_backup before_retiring_oldsite

# 3. Permanently inactivate (preserves history)
bl_db_inactivate oldsite

# 4. Verify it's no longer in active listings
bl_site_list
```

## Data Backup and Recovery

### Regular Backups
```bash
# Create timestamped backup
bl_db_backup

# Create named backup before major changes
bl_db_backup before_major_update
```

### Recovery
```bash
# List available backups
bl_db_restore invalid_name_to_see_list

# Restore from backup
bl_db_restore before_major_update
```

## Security Considerations

1. **User Restrictions**: All tools verify they're running as the configured user (`BL_USER`)
2. **File Permissions**: Tools automatically create backups before making changes
3. **IP Limiting**: Management station IP is configurable for emergency access
4. **Configuration Backups**: PHP config files are automatically backed up before modification

## File Locations

- **Tools Directory**: `/opt/bl_tools` (or custom installation directory)
- **Data File**: `{tools_directory}/bl_site.data`
- **Backups**: `{tools_directory}/bl_site.data.backup.*`
- **Common Functions**: `{tools_directory}/bl_common.sh`

## Error Handling

- All tools include comprehensive error checking
- Failed operations preserve original data
- Automatic backups prevent data loss
- Color-coded output indicates status (red=error, yellow=warning, green=success)

## Troubleshooting

### Common Issues

1. **"bl_common.sh not found"**
   - Ensure all tools are in the same directory
   - Check that `bl_common.sh` was extracted properly

2. **"Must run as user 'nsp'"**
   - Switch to the correct user: `sudo -u nsp bl_site_list`
   - Or adjust `BL_USER` in `bl_common.sh`

3. **"Config file not found"**
   - Verify `fs_base_path` is correct
   - Ensure `in/conf/local.override.config.php` exists in the site directory

4. **Git operations fail**
   - Check that directories contain valid Git repositories
   - Verify user has access to remote repositories

### Getting Help

Each tool supports `--help` or `-h` for usage information:
```bash
bl_site_list --help
bl_db_add --help
```

## Version Information

This documentation covers BL Site Management Tools version 1.2.1. For updates and additional information, check the tool header comments.

#=== FILE_SEPARATOR ===
# File: bl_site_config_delete_backups
#!/bin/bash
# bl_site_config_delete_backups - Delete config backup files for sites

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 [site_name|--all] [--dry-run]"
    echo "  site_name - Clean backups for specific site"
    echo "  --all     - Clean backups for all active sites"
    echo "  --dry-run - Show what would be deleted without actually deleting"
    exit 1
}

delete_config_backups() {
    local site_name="$1"
    local fs_base="$2"
    local dry_run="$3"
    
    local config_dir="$(dirname "$fs_base$BL_CONFIG_FILE_PATH")"
    local config_filename="$(basename "$BL_CONFIG_FILE_PATH")"
    
    info_msg "=== Cleaning config backups for: $site_name ==="
    
    if [[ ! -d "$config_dir" ]]; then
        warning_msg "Config directory does not exist: $config_dir"
        return 1
    fi
    
    # Find backup files
    local backup_files=("$config_dir"/"$config_filename".backup.*)
    local backup_count=0
    local deleted_count=0
    
    # Check if any backup files exist
    for backup_file in "${backup_files[@]}"; do
        if [[ -f "$backup_file" ]]; then
            ((backup_count++))
            
            if [[ "$dry_run" == "true" ]]; then
                echo "  Would delete: $backup_file"
            else
                if rm "$backup_file" 2>/dev/null; then
                    echo "  Deleted: $backup_file"
                    ((deleted_count++))
                else
                    error_msg "  Failed to delete: $backup_file"
                fi
            fi
        fi
    done
    
    if [[ $backup_count -eq 0 ]]; then
        info_msg "  No backup files found for $site_name"
    else
        if [[ "$dry_run" == "true" ]]; then
            info_msg "  Found $backup_count backup files for $site_name (dry-run mode)"
        else
            success_msg "  Deleted $deleted_count of $backup_count backup files for $site_name"
        fi
    fi
    
    echo
}

main() {
    check_user
    init_data_file
    
    if [[ $# -lt 1 ]]; then
        usage
    fi
    
    local target="$1"
    local dry_run="false"
    
    # Check for dry-run flag
    if [[ "$2" == "--dry-run" ]] || [[ "$1" == "--dry-run" ]]; then
        dry_run="true"
        if [[ "$1" == "--dry-run" ]]; then
            target="$2"
        fi
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        warning_msg "DRY-RUN MODE: No files will be deleted"
        echo
    fi
    
    if [[ "$target" == "--all" ]]; then
        # Process all active sites
        local total_sites=0
        while IFS='|' read -r name type status fs_base url_base notes created updated inactivated; do
            if [[ -n "$name" ]]; then
                ((total_sites++))
                delete_config_backups "$name" "$fs_base" "$dry_run"
            fi
        done < <(get_active_sites)
        
        if [[ $total_sites -eq 0 ]]; then
            warning_msg "No active sites found"
        fi
    else
        # Process specific site
        local site_name="$target"
        if ! site_exists "$site_name"; then
            error_msg "Site '$site_name' does not exist"
            exit 1
        fi
        
        local fs_base=$(get_site_fs_base "$site_name")
        delete_config_backups "$site_name" "$fs_base" "$dry_run"
    fi
    
    if [[ "$dry_run" == "true" ]]; then
        echo
        info_msg "Dry-run complete. Run without --dry-run to actually delete files."
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_git_prune
#!/bin/bash
# bl_git_prune - Prune remote tracking branches on site(s)

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 [site_name|--all]"
    echo "  site_name - Prune remote branches on specific site"
    echo "  --all     - Prune remote branches on all sites"
    echo ""
    echo "Runs 'git fetch -a -p' to fetch all remotes and prune deleted branches"
    exit 1
}

check_git_prune() {
    local site_name="$1"
    local fs_base="$2"
    
    info_msg "=== Git Prune for $site_name ==="
    
    if [[ ! -d "$fs_base" ]]; then
        error_msg "Directory does not exist: $fs_base"
        return 1
    fi
    
    if [[ ! -d "$fs_base/.git" ]]; then
        warning_msg "Not a git repository: $fs_base"
        return 1
    fi
    
    cd "$fs_base" || return 1
    
    echo "Fetching all remotes and pruning deleted branches..."
    git fetch -a -p
    echo
}

main() {
    check_user
    init_data_file
    
    if [[ $# -ne 1 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        usage
    fi
    
    if [[ "$1" == "--all" ]]; then
        # Process all active sites
        get_active_sites | while IFS='|' read -r name type status fs_base url_base notes created updated inactivated; do
            if [[ -n "$name" ]]; then
                check_git_prune "$name" "$fs_base"
            fi
        done
    else
        # Process specific site
        local site_name="$1"
        if ! site_exists "$site_name"; then
            error_msg "Site '$site_name' does not exist"
            exit 1
        fi
        
        local fs_base=$(get_site_fs_base "$site_name")
        check_git_prune "$site_name" "$fs_base"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_git_branch_cleanup
#!/bin/bash
# bl_git_branch_cleanup - Clean up local branches with deleted remote tracking

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 [site_name|--all] [--delete-branches]"
    echo "  site_name        - Check/clean branches on specific site"
    echo "  --all            - Check/clean branches on all sites"
    echo "  --delete-branches - Actually delete the branches (default: just list)"
    echo ""
    echo "Lists or deletes local branches whose remote tracking branch is gone"
    exit 1
}

check_git_branch_cleanup() {
    local site_name="$1"
    local fs_base="$2"
    local delete_branches="$3"
    
    info_msg "=== Git Branch Cleanup for $site_name ==="
    
    if [[ ! -d "$fs_base" ]]; then
        error_msg "Directory does not exist: $fs_base"
        return 1
    fi
    
    if [[ ! -d "$fs_base/.git" ]]; then
        warning_msg "Not a git repository: $fs_base"
        return 1
    fi
    
    cd "$fs_base" || return 1
    
    # First, fetch with prune to ensure tracking info is up to date
    echo "Updating remote tracking information..."
    git fetch -p
    
    # Find branches with gone remote tracking
    local gone_branches
    gone_branches=$(git branch -vv | grep "\[gone\]" | awk '{print $1}')
    
    if [[ -z "$gone_branches" ]]; then
        echo "No branches with deleted remote tracking found."
    else
        if [[ "$delete_branches" == "true" ]]; then
            echo "Deleting branches with gone remote tracking:"
            echo "$gone_branches" | while read -r branch; do
                echo "  Deleting branch: $branch"
                git branch -D "$branch"
            done
        else
            echo "Found branches with deleted remote tracking:"
            echo "$gone_branches" | while read -r branch; do
                echo "  $branch"
            done
            echo ""
            echo "Run with --delete-branches to remove these branches"
        fi
    fi
    echo
}

main() {
    check_user
    init_data_file
    
    if [[ $# -lt 1 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        usage
    fi
    
    local target="$1"
    local delete_branches="false"
    
    # Check for --delete-branches flag
    if [[ "$2" == "--delete-branches" ]] || [[ "$1" == "--delete-branches" ]]; then
        delete_branches="true"
        if [[ "$1" == "--delete-branches" ]]; then
            target="$2"
            if [[ -z "$target" ]]; then
                usage
            fi
        fi
    fi
    
    if [[ "$target" == "--all" ]]; then
        # Process all active sites
        get_active_sites | while IFS='|' read -r name type status fs_base url_base notes created updated inactivated; do
            if [[ -n "$name" ]]; then
                check_git_branch_cleanup "$name" "$fs_base" "$delete_branches"
            fi
        done
    else
        # Process specific site
        local site_name="$target"
        if ! site_exists "$site_name"; then
            error_msg "Site '$site_name' does not exist"
            exit 1
        fi
        
        local fs_base=$(get_site_fs_base "$site_name")
        check_git_branch_cleanup "$site_name" "$fs_base" "$delete_branches"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_db_add
#!/bin/bash
# bl_db_add - Add a new site entry

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 <short_name> <type> <status> <fs_base_path> <url_base> [notes]"
    echo "Types: ${VALID_TYPES[*]}"
    echo "Statuses: ${VALID_STATUSES[*]}"
    exit 1
}

main() {
    check_user
    init_data_file
    
    if [[ $# -lt 5 ]]; then
        usage
    fi
    
    local short_name="$1"
    local type="$2"
    local status="$3"
    local fs_base_path="$4"
    local url_base="$5"
    local notes="${6:-}"
    local timestamp=$(get_timestamp)
    
    # Validate inputs
    if ! validate_type "$type"; then
        error_msg "Invalid type: $type. Valid types: ${VALID_TYPES[*]}"
        exit 1
    fi
    
    if ! validate_status "$status"; then
        error_msg "Invalid status: $status. Valid statuses: ${VALID_STATUSES[*]}"
        exit 1
    fi
    
    if site_exists "$short_name"; then
        error_msg "Site '$short_name' already exists"
        exit 1
    fi
    
    # Add new site (with empty inactivated field)
    echo "${short_name}|${type}|${status}|${fs_base_path}|${url_base}|${notes}|${timestamp}|${timestamp}|" >> "$BL_DATA_FILE"
    success_msg "Site '$short_name' added successfully"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_db_update
#!/bin/bash
# bl_db_update - Update an existing site entry

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 <short_name> [--type <type>] [--status <status>] [--fs-base-path <path>] [--url-base <url>] [--notes <notes>]"
    echo "Types: ${VALID_TYPES[*]}"
    echo "Statuses: ${VALID_STATUSES[*]}"
    exit 1
}

main() {
    check_user
    init_data_file
    
    if [[ $# -lt 2 ]]; then
        usage
    fi
    
    local short_name="$1"
    shift
    
    if ! site_exists "$short_name"; then
        error_msg "Site '$short_name' does not exist"
        exit 1
    fi
    
    # Get current data
    local current_data=$(get_site_data "$short_name")
    IFS='|' read -r c_name c_type c_status c_fs_base c_url_base c_notes c_created c_updated c_inactivated <<< "$current_data"
    
    # Parse arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                if ! validate_type "$2"; then
                    error_msg "Invalid type: $2"
                    exit 1
                fi
                c_type="$2"
                shift 2
                ;;
            --status)
                if ! validate_status "$2"; then
                    error_msg "Invalid status: $2"
                    exit 1
                fi
                c_status="$2"
                shift 2
                ;;
            --fs-base-path)
                c_fs_base="$2"
                shift 2
                ;;
            --url-base)
                c_url_base="$2"
                shift 2
                ;;
            --notes)
                c_notes="$2"
                shift 2
                ;;
            *)
                error_msg "Unknown option: $1"
                usage
                ;;
        esac
    done
    
    # Update timestamp
    local timestamp=$(get_timestamp)
    
    # Remove old entry and add updated one (preserve inactivated status)
    grep -v "^${short_name}|" "$BL_DATA_FILE" > "${BL_DATA_FILE}.tmp"
    echo "${c_name}|${c_type}|${c_status}|${c_fs_base}|${c_url_base}|${c_notes}|${c_created}|${timestamp}|${c_inactivated}" >> "${BL_DATA_FILE}.tmp"
    mv "${BL_DATA_FILE}.tmp" "$BL_DATA_FILE"
    
    success_msg "Site '$short_name' updated successfully"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_db_inactivate
#!/bin/bash
# bl_db_inactivate - Inactivate a site (set inactivation timestamp)

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 <short_name>"
    exit 1
}

main() {
    check_user
    init_data_file
    
    if [[ $# -ne 1 ]]; then
        usage
    fi
    
    local short_name="$1"
    
    if ! site_exists "$short_name"; then
        error_msg "Active site '$short_name' does not exist"
        exit 1
    fi
    
    # Get current data
    local current_data=$(get_site_data "$short_name")
    IFS='|' read -r c_name c_type c_status c_fs_base c_url_base c_notes c_created c_updated c_inactivated <<< "$current_data"
    
    # Set inactivation timestamp
    local timestamp=$(get_timestamp)
    
    # Remove old entry and add inactivated one
    grep -v "^${short_name}|" "$BL_DATA_FILE" > "${BL_DATA_FILE}.tmp"
    echo "${c_name}|${c_type}|${c_status}|${c_fs_base}|${c_url_base}|${c_notes}|${c_created}|${c_updated}|${timestamp}" >> "${BL_DATA_FILE}.tmp"
    mv "${BL_DATA_FILE}.tmp" "$BL_DATA_FILE"
    
    success_msg "Site '$short_name' inactivated on $timestamp"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_site_list
#!/bin/bash
# bl_site_list - List and search sites

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 [options]"
    echo "Options:"
    echo "  --type <type>     Filter by type"
    echo "  --status <status> Filter by status"
    echo "  --search <term>   Search in all fields"
    echo "  --sort <field>    Sort by field (1-8)"
    echo "  --format <fmt>    Output format: table, csv, json"
    exit 1
}

print_header() {
    printf "%-15s %-8s %-10s %-30s %-30s %-20s %-20s %-20s\n" \
        "SHORT_NAME" "TYPE" "STATUS" "FS_BASE_PATH" "URL_BASE" "NOTES" "CREATED" "UPDATED"
    printf "%s\n" "$(printf '=%.0s' {1..150})"
}

print_site() {
    local data="$1"
    IFS='|' read -r name type status fs_base url_base notes created updated inactivated <<< "$data"
    printf "%-15s %-8s %-10s %-30s %-30s %-20s %-20s %-20s\n" \
        "$name" "$type" "$status" "$fs_base" "$url_base" "$notes" "$created" "$updated"
}

main() {
    check_user
    init_data_file
    
    local filter_type=""
    local filter_status=""
    local search_term=""
    local sort_field=""
    local output_format="table"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --type)
                filter_type="$2"
                shift 2
                ;;
            --status)
                filter_status="$2"
                shift 2
                ;;
            --search)
                search_term="$2"
                shift 2
                ;;
            --sort)
                sort_field="$2"
                shift 2
                ;;
            --format)
                output_format="$2"
                shift 2
                ;;
            *)
                usage
                ;;
        esac
    done
    
    # Get active sites data
    local data_lines=$(get_active_sites)
    
    # Apply filters
    if [[ -n "$filter_type" ]]; then
        data_lines=$(echo "$data_lines" | awk -F'|' -v type="$filter_type" '$2 == type')
    fi
    
    if [[ -n "$filter_status" ]]; then
        data_lines=$(echo "$data_lines" | awk -F'|' -v status="$filter_status" '$3 == status')
    fi
    
    if [[ -n "$search_term" ]]; then
        data_lines=$(echo "$data_lines" | grep -i "$search_term")
    fi
    
    # Apply sorting
    if [[ -n "$sort_field" ]]; then
        data_lines=$(echo "$data_lines" | sort -t'|' -k"$sort_field")
    fi
    
    # Output
    case "$output_format" in
        table)
            print_header
            while IFS= read -r line; do
                [[ -n "$line" ]] && print_site "$line"
            done <<< "$data_lines"
            ;;
        csv)
            echo "$BL_DATA_HEADER"
            echo "$data_lines"
            ;;
        json)
            echo "["
            local first=true
            while IFS= read -r line; do
                if [[ -n "$line" ]]; then
                    [[ "$first" == false ]] && echo ","
                    IFS='|' read -r name type status fs_base url_base notes created updated inactivated <<< "$line"
                    echo "  {"
                    echo "    \"short_name\": \"$name\","
                    echo "    \"type\": \"$type\","
                    echo "    \"status\": \"$status\","
                    echo "    \"fs_base_path\": \"$fs_base\","
                    echo "    \"url_base\": \"$url_base\","
                    echo "    \"notes\": \"$notes\","
                    echo "    \"created\": \"$created\","
                    echo "    \"last_updated\": \"$updated\""
                    echo -n "  }"
                    first=false
                fi
            done <<< "$data_lines"
            echo
            echo "]"
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_git_status
#!/bin/bash
# bl_git_status - Run git status on site(s)

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 [site_name|--all]"
    echo "  site_name - Check specific site"
    echo "  --all     - Check all sites"
    exit 1
}

check_git_status() {
    local site_name="$1"
    local fs_base="$2"
    
    info_msg "=== Git Status for $site_name ==="
    
    if [[ ! -d "$fs_base" ]]; then
        error_msg "Directory does not exist: $fs_base"
        return 1
    fi
    
    if [[ ! -d "$fs_base/.git" ]]; then
        warning_msg "Not a git repository: $fs_base"
        return 1
    fi
    
    cd "$fs_base" || return 1
    git status
    echo
}

main() {
    check_user
    init_data_file
    
    if [[ $# -ne 1 ]]; then
        usage
    fi
    
    if [[ "$1" == "--all" ]]; then
        # Process all active sites
        get_active_sites | while IFS='|' read -r name type status fs_base url_base notes created updated inactivated; do
            if [[ -n "$name" ]]; then
                check_git_status "$name" "$fs_base"
            fi
        done
    else
        # Process specific site
        local site_name="$1"
        if ! site_exists "$site_name"; then
            error_msg "Site '$site_name' does not exist"
            exit 1
        fi
        
        local fs_base=$(get_site_fs_base "$site_name")
        check_git_status "$site_name" "$fs_base"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_git_pull
#!/bin/bash
# bl_git_pull - Run git pull on site(s)

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 [site_name|--all] [--force]"
    echo "  site_name - Pull specific site"
    echo "  --all     - Pull all sites"
    echo "  --force   - Force pull even if working directory is dirty"
    exit 1
}

check_git_pull() {
    local site_name="$1"
    local fs_base="$2"
    local force="$3"
    
    info_msg "=== Git Pull for $site_name ==="
    
    if [[ ! -d "$fs_base" ]]; then
        error_msg "Directory does not exist: $fs_base"
        return 1
    fi
    
    if [[ ! -d "$fs_base/.git" ]]; then
        warning_msg "Not a git repository: $fs_base"
        return 1
    fi
    
    cd "$fs_base" || return 1
    
    # Check if working directory is clean
    if [[ "$force" != "true" ]] && ! git diff-index --quiet HEAD --; then
        warning_msg "Working directory is dirty for $site_name. Use --force to pull anyway."
        return 1
    fi
    
    git pull
    echo
}

main() {
    check_user
    init_data_file
    
    if [[ $# -lt 1 ]]; then
        usage
    fi
    
    local target="$1"
    local force="false"
    
    if [[ "$2" == "--force" ]] || [[ "$1" == "--force" && "$2" != "" ]]; then
        force="true"
        if [[ "$1" == "--force" ]]; then
            target="$2"
        fi
    fi
    
    if [[ "$target" == "--all" ]]; then
        # Process all active sites
        get_active_sites | while IFS='|' read -r name type status fs_base url_base notes created updated inactivated; do
            if [[ -n "$name" ]]; then
                check_git_pull "$name" "$fs_base" "$force"
            fi
        done
    else
        # Process specific site
        local site_name="$target"
        if ! site_exists "$site_name"; then
            error_msg "Site '$site_name' does not exist"
            exit 1
        fi
        
        local fs_base=$(get_site_fs_base "$site_name")
        check_git_pull "$site_name" "$fs_base" "$force"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_git_checkout
#!/bin/bash
# bl_git_checkout - Checkout a specific branch on site(s)

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 <branch> <site_name|--all>"
    echo "  branch    - Git branch to checkout"
    echo "  site_name - Checkout branch on specific site"
    echo "  --all     - Checkout branch on all sites"
    echo ""
    echo "Example: $0 develop mysite"
    echo "Example: $0 main --all"
    exit 1
}

check_git_checkout() {
    local branch="$1"
    local site_name="$2"
    local fs_base="$3"
    
    info_msg "=== Git Checkout '$branch' for $site_name ==="
    
    if [[ ! -d "$fs_base" ]]; then
        error_msg "Directory does not exist: $fs_base"
        return 1
    fi
    
    if [[ ! -d "$fs_base/.git" ]]; then
        warning_msg "Not a git repository: $fs_base"
        return 1
    fi
    
    cd "$fs_base" || return 1
    
    # Check if working directory is clean
    if ! git diff-index --quiet HEAD -- 2>/dev/null; then
        warning_msg "Working directory has uncommitted changes for $site_name"
        echo "  Use 'git stash' or commit changes before switching branches"
        return 1
    fi
    
    # Fetch latest branch information
    echo "Fetching latest branch information..."
    git fetch --quiet
    
    # Check if branch exists (locally or remotely)
    if git show-ref --verify --quiet "refs/heads/$branch"; then
        # Local branch exists
        echo "Checking out local branch: $branch"
        git checkout "$branch"
    elif git show-ref --verify --quiet "refs/remotes/origin/$branch"; then
        # Remote branch exists
        echo "Checking out remote branch: origin/$branch"
        git checkout -b "$branch" "origin/$branch" 2>/dev/null || git checkout "$branch"
    else
        error_msg "Branch '$branch' not found locally or on remote"
        return 1
    fi
    
    # Show current branch status
    echo "Current branch: $(git branch --show-current)"
    echo
}

main() {
    check_user
    init_data_file
    
    if [[ $# -ne 2 ]] || [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]]; then
        usage
    fi
    
    local branch="$1"
    local target="$2"
    
    if [[ "$target" == "--all" ]]; then
        # Process all active sites
        local success_count=0
        local fail_count=0
        local temp_result=$(mktemp)
        
        while IFS='|' read -r name type status fs_base url_base notes created updated inactivated; do
            if [[ -n "$name" ]]; then
                if check_git_checkout "$branch" "$name" "$fs_base"; then
                    echo "success" >> "$temp_result"
                else
                    echo "fail" >> "$temp_result"
                fi
            fi
        done < <(get_active_sites)
        
        # Count results
        success_count=$(grep -c "success" "$temp_result" 2>/dev/null || echo 0)
        fail_count=$(grep -c "fail" "$temp_result" 2>/dev/null || echo 0)
        rm -f "$temp_result"
        
        echo
        info_msg "=== Checkout Summary ==="
        if [[ $fail_count -eq 0 ]]; then
            success_msg "Successfully checked out '$branch' on all sites"
        else
            warning_msg "Checked out '$branch' on $success_count sites, failed on $fail_count sites"
        fi
    else
        # Process specific site
        local site_name="$target"
        if ! site_exists "$site_name"; then
            error_msg "Site '$site_name' does not exist"
            exit 1
        fi
        
        local fs_base=$(get_site_fs_base "$site_name")
        if check_git_checkout "$branch" "$site_name" "$fs_base"; then
            success_msg "Successfully checked out '$branch' on $site_name"
        else
            error_msg "Failed to checkout '$branch' on $site_name"
            exit 1
        fi
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_disable_site
#!/bin/bash
# bl_disable_site - Disable site by setting staff_open and client_open to 0

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 [site_name|--all]"
    exit 1
}

disable_site() {
    local site_name="$1"
    local fs_base="$2"
    local config_file="$fs_base$BL_CONFIG_FILE_PATH"
    
    info_msg "=== Disabling site: $site_name ==="
    
    if [[ ! -f "$config_file" ]]; then
        error_msg "Config file not found: $config_file"
        return 1
    fi
    
    edit_php_config "$config_file" "SITE.staff_open" "0"
    edit_php_config "$config_file" "SITE.client_open" "0"
    
    success_msg "Site $site_name disabled"
}

main() {
    check_user
    init_data_file
    
    if [[ $# -ne 1 ]]; then
        usage
    fi
    
    if [[ "$1" == "--all" ]]; then
        # Process all active sites
        get_active_sites | while IFS='|' read -r name type status fs_base url_base notes created updated inactivated; do
            if [[ -n "$name" ]]; then
                disable_site "$name" "$fs_base"
            fi
        done
    else
        # Process specific site
        local site_name="$1"
        if ! site_exists "$site_name"; then
            error_msg "Site '$site_name' does not exist"
            exit 1
        fi
        
        local fs_base=$(get_site_fs_base "$site_name")
        disable_site "$site_name" "$fs_base"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_enable_site
#!/bin/bash
# bl_enable_site - Enable site by setting staff_open and client_open to 1

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 [site_name|--all]"
    exit 1
}

enable_site() {
    local site_name="$1"
    local fs_base="$2"
    local config_file="$fs_base$BL_CONFIG_FILE_PATH"
    
    info_msg "=== Enabling site: $site_name ==="
    
    if [[ ! -f "$config_file" ]]; then
        error_msg "Config file not found: $config_file"
        return 1
    fi
    
    edit_php_config "$config_file" "SITE.staff_open" "1"
    edit_php_config "$config_file" "SITE.client_open" "1"
    
    success_msg "Site $site_name enabled"
}

main() {
    check_user
    init_data_file
    
    if [[ $# -ne 1 ]]; then
        usage
    fi
    
    if [[ "$1" == "--all" ]]; then
        # Process all active sites
        get_active_sites | while IFS='|' read -r name type status fs_base url_base notes created updated inactivated; do
            if [[ -n "$name" ]]; then
                enable_site "$name" "$fs_base"
            fi
        done
    else
        # Process specific site
        local site_name="$1"
        if ! site_exists "$site_name"; then
            error_msg "Site '$site_name' does not exist"
            exit 1
        fi
        
        local fs_base=$(get_site_fs_base "$site_name")
        enable_site "$site_name" "$fs_base"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_limit_site
#!/bin/bash
# bl_limit_site - Limit site access to management station IP

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 [site_name|--all]"
    exit 1
}

limit_site() {
    local site_name="$1"
    local fs_base="$2"
    local config_file="$fs_base$BL_CONFIG_FILE_PATH"
    
    info_msg "=== Limiting site access: $site_name ==="
    
    if [[ ! -f "$config_file" ]]; then
        error_msg "Config file not found: $config_file"
        return 1
    fi
    
    edit_php_config "$config_file" "SITE.staff_limit_src" "1"
    edit_php_config "$config_file" "SITE.client_limit_src" "1"
    edit_php_config "$config_file" "SITE.limit_src_ip" "[\"$MANAGEMENT_STATION_IP\"]"
    
    success_msg "Site $site_name limited to management station IP: $MANAGEMENT_STATION_IP"
}

main() {
    check_user
    init_data_file
    
    if [[ $# -ne 1 ]]; then
        usage
    fi
    
    if [[ "$1" == "--all" ]]; then
        # Process all active sites
        get_active_sites | while IFS='|' read -r name type status fs_base url_base notes created updated inactivated; do
            if [[ -n "$name" ]]; then
                limit_site "$name" "$fs_base"
            fi
        done
    else
        # Process specific site
        local site_name="$1"
        if ! site_exists "$site_name"; then
            error_msg "Site '$site_name' does not exist"
            exit 1
        fi
        
        local fs_base=$(get_site_fs_base "$site_name")
        limit_site "$site_name" "$fs_base"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_unlimit_site
#!/bin/bash
# bl_unlimit_site - Remove site access limitations

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 [site_name|--all]"
    exit 1
}

unlimit_site() {
    local site_name="$1"
    local fs_base="$2"
    local config_file="$fs_base$BL_CONFIG_FILE_PATH"
    
    info_msg "=== Removing site access limitations: $site_name ==="
    
    if [[ ! -f "$config_file" ]]; then
        error_msg "Config file not found: $config_file"
        return 1
    fi
    
    edit_php_config "$config_file" "SITE.staff_limit_src" "0"
    edit_php_config "$config_file" "SITE.client_limit_src" "0"
    
    success_msg "Site $site_name access limitations removed"
}

main() {
    check_user
    init_data_file
    
    if [[ $# -ne 1 ]]; then
        usage
    fi
    
    if [[ "$1" == "--all" ]]; then
        # Process all active sites
        get_active_sites | while IFS='|' read -r name type status fs_base url_base notes created updated inactivated; do
            if [[ -n "$name" ]]; then
                unlimit_site "$name" "$fs_base"
            fi
        done
    else
        # Process specific site
        local site_name="$1"
        if ! site_exists "$site_name"; then
            error_msg "Site '$site_name' does not exist"
            exit 1
        fi
        
        local fs_base=$(get_site_fs_base "$site_name")
        unlimit_site "$site_name" "$fs_base"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_site_show
#!/bin/bash
# bl_site_show - Show detailed information for a specific site

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 <site_name>"
    exit 1
}

main() {
    check_user
    init_data_file
    
    if [[ $# -ne 1 ]]; then
        usage
    fi
    
    local site_name="$1"
    
    if ! site_exists "$site_name"; then
        error_msg "Site '$site_name' does not exist"
        exit 1
    fi
    
    local site_data=$(get_site_data "$site_name")
    IFS='|' read -r name type status fs_base url_base notes created updated inactivated <<< "$site_data"
    
    echo -e "${CYAN}=== Site Details: $name ===${NC}"
    echo "Short Name:     $name"
    echo "Type:           $type"
    echo "Status:         $status"
    echo "FS Base Path:   $fs_base"
    echo "URL Base:       $url_base"
    echo "Notes:          $notes"
    echo "Created:        $created"
    echo "Last Updated:   $updated"
    echo
    
    # Check if directory exists
    if [[ -d "$fs_base" ]]; then
        echo -e "${GREEN}✓ Directory exists${NC}"
        
        # Check if it's a git repo
        if [[ -d "$fs_base/.git" ]]; then
            echo -e "${GREEN}✓ Git repository${NC}"
            cd "$fs_base"
            echo "Git branch:     $(git branch --show-current 2>/dev/null || echo 'Unknown')"
            echo "Last commit:    $(git log -1 --format='%h - %s (%cr)' 2>/dev/null || echo 'No commits')"
        else
            echo -e "${YELLOW}⚠ Not a git repository${NC}"
        fi
        
        # Check config file
        local config_file="$fs_base$BL_CONFIG_FILE_PATH"
        if [[ -f "$config_file" ]]; then
            echo -e "${GREEN}✓ Config file exists${NC}"
            
            # Try to extract current settings
            local staff_open=$(php -r "include '$config_file'; echo isset(\$BS_CONF['SITE']['staff_open']) ? \$BS_CONF['SITE']['staff_open'] : 'N/A';" 2>/dev/null || echo "Error reading")
            local client_open=$(php -r "include '$config_file'; echo isset(\$BS_CONF['SITE']['client_open']) ? \$BS_CONF['SITE']['client_open'] : 'N/A';" 2>/dev/null || echo "Error reading")
            
            echo "Staff Access:   $staff_open"
            echo "Client Access:  $client_open"
        else
            echo -e "${YELLOW}⚠ Config file missing${NC}"
        fi
    else
        echo -e "${RED}✗ Directory does not exist${NC}"
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_db_backup
#!/bin/bash
# bl_db_backup - Create backup of site data file

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 [backup_name]"
    echo "If no backup_name provided, uses timestamp"
    exit 1
}

main() {
    check_user
    init_data_file
    
    local backup_name=""
    if [[ $# -eq 1 ]]; then
        backup_name="$1"
    else
        backup_name="auto_$(date '+%Y%m%d_%H%M%S')"
    fi
    
    local backup_file="${BL_DATA_FILE}.backup.${backup_name}"
    
    if [[ -f "$backup_file" ]]; then
        error_msg "Backup file already exists: $backup_file"
        exit 1
    fi
    
    cp "$BL_DATA_FILE" "$backup_file"
    success_msg "Backup created: $backup_file"
    
    # List all backups
    echo
    info_msg "Available backups:"
    ls -la "${BL_DATA_FILE}.backup."* 2>/dev/null | awk '{print $9, $5, $6, $7, $8}' | column -t
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_db_restore
#!/bin/bash
# bl_db_restore - Restore site data from backup

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 <backup_name>"
    echo "Available backups:"
    ls -1 "${BL_DATA_FILE}.backup."* 2>/dev/null | sed 's/.*\.backup\./  /'
    exit 1
}

main() {
    check_user
    
    if [[ $# -ne 1 ]]; then
        usage
    fi
    
    local backup_name="$1"
    local backup_file="${BL_DATA_FILE}.backup.${backup_name}"
    
    if [[ ! -f "$backup_file" ]]; then
        error_msg "Backup file not found: $backup_file"
        usage
    fi
    
    # Create current backup before restore
    if [[ -f "$BL_DATA_FILE" ]]; then
        local current_backup="${BL_DATA_FILE}.backup.pre_restore_$(date '+%Y%m%d_%H%M%S')"
        cp "$BL_DATA_FILE" "$current_backup"
        info_msg "Current data backed up to: $current_backup"
    fi
    
    # Restore
    cp "$backup_file" "$BL_DATA_FILE"
    success_msg "Data restored from: $backup_file"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_health_check
#!/bin/bash
# bl_health_check - Comprehensive health check for all sites

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 [--verbose] [--fix]"
    echo "  --verbose  Show detailed output"
    echo "  --fix      Attempt to fix common issues"
    exit 1
}

check_site_health() {
    local site_name="$1"
    local fs_base="$2"
    local url_base="$3"
    local verbose="$4"
    local fix="$5"
    local issues=0
    
    if [[ "$verbose" == "true" ]]; then
        info_msg "=== Health Check: $site_name ==="
    fi
    
    # Check directory exists
    if [[ ! -d "$fs_base" ]]; then
        echo -e "${RED}✗ $site_name: Directory missing: $fs_base${NC}"
        ((issues++))
        if [[ "$fix" == "true" ]]; then
            warning_msg "  Cannot auto-fix missing directory"
        fi
    else
        if [[ "$verbose" == "true" ]]; then
            echo -e "${GREEN}✓ $site_name: Directory exists${NC}"
        fi
        
        # Check git repository
        if [[ ! -d "$fs_base/.git" ]]; then
            echo -e "${YELLOW}⚠ $site_name: Not a git repository${NC}"
            ((issues++))
        else
            if [[ "$verbose" == "true" ]]; then
                echo -e "${GREEN}✓ $site_name: Git repository${NC}"
            fi
            
            # Check git status
            cd "$fs_base"
            if ! git status &>/dev/null; then
                echo -e "${RED}✗ $site_name: Git repository corrupted${NC}"
                ((issues++))
            fi
        fi
        
        # Check config file
        local config_file="$fs_base$BL_CONFIG_FILE_PATH"
        if [[ ! -f "$config_file" ]]; then
            echo -e "${YELLOW}⚠ $site_name: Config file missing${NC}"
            ((issues++))
            if [[ "$fix" == "true" ]]; then
                warning_msg "  Cannot auto-create config file (site-specific)"
            fi
        else
            if [[ "$verbose" == "true" ]]; then
                echo -e "${GREEN}✓ $site_name: Config file exists${NC}"
            fi
            
            # Check config syntax
            if ! php -l "$config_file" &>/dev/null; then
                echo -e "${RED}✗ $site_name: Config file has syntax errors${NC}"
                ((issues++))
            fi
        fi
        
        # Check permissions
        if [[ ! -w "$fs_base" ]]; then
            echo -e "${YELLOW}⚠ $site_name: Directory not writable${NC}"
            ((issues++))
            if [[ "$fix" == "true" ]]; then
                info_msg "  Fixing permissions..."
                sudo chown -R "$BL_USER:$BL_USER" "$fs_base"
            fi
        fi
    fi
    
    return $issues
}

main() {
    check_user
    init_data_file
    
    local verbose="false"
    local fix="false"
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            --verbose)
                verbose="true"
                shift
                ;;
            --fix)
                fix="true"
                shift
                ;;
            *)
                usage
                ;;
        esac
    done
    
    local total_issues=0
    local total_sites=0
    
    info_msg "=== BL Tools Health Check ==="
    echo
    
    # Check data file
    if [[ ! -f "$BL_DATA_FILE" ]]; then
        error_msg "Data file missing: $BL_DATA_FILE"
        exit 1
    fi
    
    # Process all active sites
    get_active_sites | while IFS='|' read -r name type status fs_base url_base notes created updated inactivated; do
        if [[ -n "$name" ]]; then
            ((total_sites++))
            check_site_health "$name" "$fs_base" "$url_base" "$verbose" "$fix"
            site_issues=$?
            ((total_issues += site_issues))
        fi
    done
    
    echo
    info_msg "=== Health Check Summary ==="
    echo "Total sites checked: $total_sites"
    if [[ $total_issues -eq 0 ]]; then
        success_msg "All sites healthy! ✓"
    else
        warning_msg "Found $total_issues issues across all sites"
        if [[ "$fix" != "true" ]]; then
            info_msg "Run with --fix to attempt automatic repairs"
        fi
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_config_get
#!/bin/bash
# bl_config_get - Get configuration values from site config files

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 <site_name> <config_key>"
    echo "Example: $0 mysite SITE.staff_open"
    exit 1
}

main() {
    check_user
    init_data_file
    
    if [[ $# -ne 2 ]]; then
        usage
    fi
    
    local site_name="$1"
    local config_key="$2"
    
    if ! site_exists "$site_name"; then
        error_msg "Site '$site_name' does not exist"
        exit 1
    fi
    
    local fs_base=$(get_site_fs_base "$site_name")
    local config_file="$fs_base$BL_CONFIG_FILE_PATH"
    
    if [[ ! -f "$config_file" ]]; then
        error_msg "Config file not found: $config_file"
        exit 1
    fi
    
    # Convert dot notation to PHP array access
    local php_key=$(echo "$config_key" | sed "s/\./', '/g")
    
    # Get the value using PHP
    local value=$(php << EOF
<?php
\$config_file = '$config_file';
include \$config_file;

\$keys = ['$php_key'];
\$current = \$BS_CONF;

foreach (\$keys as \$key) {
    if (isset(\$current[\$key])) {
        \$current = \$current[\$key];
    } else {
        echo "KEY_NOT_FOUND";
        exit(1);
    }
}

if (is_array(\$current)) {
    echo json_encode(\$current);
} else {
    echo \$current;
}
EOF
)
    
    if [[ "$value" == "KEY_NOT_FOUND" ]]; then
        error_msg "Configuration key '$config_key' not found"
        exit 1
    fi
    
    echo "$value"
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

#=== FILE_SEPARATOR ===
# File: bl_config_set
#!/bin/bash
# bl_config_set - Set configuration values in site config files

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 <site_name> <config_key> <value>"
    echo "Example: $0 mysite SITE.staff_open 1"
    echo "Example: $0 mysite SITE.limit_src_ip '[\"1.1.1.1\",\"2.2.2.2\"]'"
    exit 1
}

main() {
    check_user
    init_data_file
    
    if [[ $# -ne 3 ]]; then
        usage
    fi
    
    local site_name="$1"
    local config_key="$2"
    local value="$3"
    
    if ! site_exists "$site_name"; then
        error_msg "Site '$site_name' does not exist"
        exit 1
    fi
    
    local fs_base=$(get_site_fs_base "$site_name")
    local config_file="$fs_base$BL_CONFIG_FILE_PATH"
    
    if [[ ! -f "$config_file" ]]; then
        error_msg "Config file not found: $config_file"
        exit 1
    fi
    
    # Use the edit_php_config function
    if edit_php_config "$config_file" "$config_key" "$value"; then
        success_msg "Configuration updated: $config_key = $value"
    else
        error_msg "Failed to update configuration"
        exit 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

echo "Usage Examples:"
echo "  bl_db_add mysite prod ok /var/www/mysite https://mysite.com"
echo "  bl_site_list --type prod --status ok"
echo "  bl_git_pull --all"
echo "  bl_git_checkout develop --all"
echo "  bl_git_branch_cleanup --all --delete-branches"
echo "  bl_disable_site mysite"
echo "  bl_health_check --verbose --fix"


#=== FILE_SEPARATOR ===
# File: bl_site_quicklist
#!/bin/bash
# bl_site_quicklist - Simplified site list (short_name, type, fs_base_path, notes)

source "$(dirname "$0")/bl_common.sh"

usage() {
    echo "Usage: $0 [--format table|csv]"
    exit 1
}

print_header() {
    printf "%-15s %-8s %-40s %-30s\n" \
        "SHORT_NAME" "TYPE" "FS_BASE_PATH" "NOTES"
    printf "%s\n" "$(printf '=%.0s' {1..100})"
}

print_site() {
    local data="$1"
    IFS='|' read -r name type status fs_base url_base notes created updated inactivated <<< "$data"
    printf "%-15s %-8s %-40s %-30s\n" \
        "$name" "$type" "$fs_base" "$notes"
}

main() {
    check_user
    init_data_file

    local output_format="table"

    if [[ $# -gt 0 ]]; then
        if [[ "$1" == "--format" ]] && [[ -n "$2" ]]; then
            output_format="$2"
        else
            usage
        fi
    fi

    local data_lines
    data_lines=$(get_active_sites)

    case "$output_format" in
        table)
            print_header
            while IFS= read -r line; do
                [[ -n "$line" ]] && print_site "$line"
            done <<< "$data_lines"
            ;;
        csv)
            echo "short_name,type,fs_base_path,notes"
            while IFS= read -r line; do
                IFS='|' read -r name type status fs_base url_base notes _ <<< "$line"
                echo "\"$name\",\"$type\",\"$fs_base\",\"$notes\""
            done <<< "$data_lines"
            ;;
        *)
            error_msg "Unsupported format: $output_format"
            usage
            ;;
    esac
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi

