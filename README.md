# This is a specialized toolset, not likely of any interrest to the general public.
## It is used to manage multiple instances of varies branches deployed to the same web server.

Copyright Thomas Stokkeland / Sauen.Com 2025 / MIT Licence

Large portions of this generated with Claude AI and ChatGPT - but they keep on screwing stuff up and wasting cycles so i did a ton myself.

* The main script will extra itself into multiple scripts in chosen dir, this was to make it portable.
* The generated file bl_site.data is your "website database"
* The below is a copy of the README in the extracted files, i just provided both here for easy finding of stuff


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

