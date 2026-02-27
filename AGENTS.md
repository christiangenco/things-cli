# Things CLI

CRUD for Things 3 todos and projects. No setup or credentials needed — uses AppleScript.

## Usage

```bash
# Lists
things inbox                              # Show Inbox todos
things today                              # Show Today todos
things upcoming                           # Show Upcoming todos
things anytime                            # Show Anytime todos
things someday                            # Show Someday todos
things logbook --limit 20                 # Show completed todos

# Todo CRUD
things add "title" [--when today|tomorrow|someday|anytime] [--deadline YYYY-MM-DD] [--tags "Tag1,Tag2"] [--project "Name"] [--notes "text"] [--checklist "a,b,c"]
things show <ID>                          # Show todo details
things edit <ID> [--name X] [--notes X] [--when X] [--deadline X] [--tags X] [--project X]
things complete <ID>                      # Mark complete
things cancel <ID>                        # Mark cancelled
things delete <ID>                        # Trash

# Search
things search "query" [--limit N]         # Search open todos by name

# Projects
things projects                           # List all projects
things project show <name-or-id>          # Show project + todos
things project add "name" [--notes X] [--area X] [--tags X] [--when X] [--deadline X]
things project edit <name-or-id> [--name X] [--notes X] [--tags X] [--deadline X]
things project complete <name-or-id>
things project delete <name-or-id>

# Tags
things tags                               # List all tags
```

All output is JSON to stdout. Use `--deadline none` or `--project none` to clear fields.
