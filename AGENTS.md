# Things CLI

CRUD for Things 3 todos and projects. No setup or credentials needed — uses AppleScript.

## Usage

```bash
cd ~/tools/things

# Lists
ruby cli.rb inbox                              # Show Inbox todos
ruby cli.rb today                              # Show Today todos
ruby cli.rb upcoming                           # Show Upcoming todos
ruby cli.rb anytime                            # Show Anytime todos
ruby cli.rb someday                            # Show Someday todos
ruby cli.rb logbook --limit 20                 # Show completed todos

# Todo CRUD
ruby cli.rb add "title" [--when today|tomorrow|someday|anytime] [--deadline YYYY-MM-DD] [--tags "Tag1,Tag2"] [--project "Name"] [--notes "text"] [--checklist "a,b,c"]
ruby cli.rb show <ID>                          # Show todo details
ruby cli.rb edit <ID> [--name X] [--notes X] [--when X] [--deadline X] [--tags X] [--project X]
ruby cli.rb complete <ID>                      # Mark complete
ruby cli.rb cancel <ID>                        # Mark cancelled
ruby cli.rb delete <ID>                        # Trash

# Search
ruby cli.rb search "query" [--limit N]         # Search open todos by name

# Projects
ruby cli.rb projects                           # List all projects
ruby cli.rb project show <name-or-id>          # Show project + todos
ruby cli.rb project add "name" [--notes X] [--area X] [--tags X] [--when X] [--deadline X]
ruby cli.rb project edit <name-or-id> [--name X] [--notes X] [--tags X] [--deadline X]
ruby cli.rb project complete <name-or-id>
ruby cli.rb project delete <name-or-id>

# Tags
ruby cli.rb tags                               # List all tags
```

All output is JSON to stdout. Use `--deadline none` or `--project none` to clear fields.
