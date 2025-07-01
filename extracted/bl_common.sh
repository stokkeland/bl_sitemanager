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

