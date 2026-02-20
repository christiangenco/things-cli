# Things CLI

A minimal CLI for Things 3 on macOS. Full CRUD for todos and projects via AppleScript.

## Requirements

- macOS with [Things 3](https://culturedcode.com/things/) installed
- Ruby (any version with `json` and `open3` in stdlib — no gems needed)

## Setup

No dependencies to install. Just use it:

```bash
cd ~/tools/things
ruby cli.rb today
```

Optionally symlink for global access:

```bash
ln -s ~/tools/things/cli.rb /usr/local/bin/things
```

## Usage

All commands output JSON to stdout.

### Lists

```bash
things inbox                              # Show Inbox todos
things today                              # Show Today todos
things upcoming                           # Show Upcoming todos
things anytime                            # Show Anytime todos
things someday                            # Show Someday todos
things logbook --limit 20                 # Show completed todos (default: all)
```

### Todos

```bash
# Create
things add "Buy groceries"                                    # Add to Inbox
things add "Fix bug" --project "MyProject"                    # Add to a project
things add "Call dentist" --when today                        # Schedule for today
things add "Due Friday" --deadline 2026-02-27                 # With deadline
things add "With notes" --notes "Some details here"           # With notes
things add "Tagged" --tags "Errand,Home"                      # With tags
things add "Multi-step" --checklist "Step 1,Step 2,Step 3"   # With checklist

# Read
things show <ID>                          # Show todo details

# Update
things edit <ID> --name "New title"       # Rename
things edit <ID> --notes "Updated notes"  # Update notes
things edit <ID> --when today             # Move to Today
things edit <ID> --deadline 2026-03-01    # Set deadline
things edit <ID> --deadline none          # Clear deadline
things edit <ID> --tags "Office"          # Set tags
things edit <ID> --project "MyProject"    # Move to project
things edit <ID> --project none           # Remove from project

# Status
things complete <ID>                      # Mark complete
things cancel <ID>                        # Mark cancelled
things delete <ID>                        # Move to Trash
```

### Search

```bash
things search "marketing"                 # Search by name (open todos only)
things search "marketing" --limit 10      # Limit results
```

### Projects

```bash
things projects                                   # List all projects
things project show "📆Habits"                     # Show project + its todos
things project show <ID>                           # Show by ID
things project add "New Project"                   # Create project
things project add "New Project" --area "Times"    # In an area
things project edit "Old Name" --name "New Name"   # Rename
things project complete "Done Project"             # Complete
things project delete "Old Project"                # Trash
```

### Tags

```bash
things tags                               # List all tags
```

## Output Format

All commands return JSON:

```json
{"ok":true,"data":{"todos":[{"id":"abc123","name":"Buy groceries","status":"open","tags":null,"deadline":null,"start_date":null,"notes":null,"project":null,"area":null}],"total":1}}
```

Errors:

```json
{"ok":false,"error":"Todo not found","code":"ERROR"}
```

## How It Works

Uses AppleScript (`osascript`) to communicate with Things 3. No database access, no URL schemes, no external dependencies. Just Ruby stdlib + AppleScript.
