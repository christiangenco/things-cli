#!/usr/bin/env ruby
# Things CLI — CRUD for Things 3 todos and projects
#
# Usage:
#   things inbox                              List Inbox todos
#   things today                              List Today todos
#   things upcoming                           List Upcoming todos
#   things anytime                            List Anytime todos
#   things someday                            List Someday todos
#   things logbook [--limit N]                List completed todos
#
#   things add "title" [options]              Create a todo
#   things show <ID>                          Show todo details
#   things edit <ID> [options]                Update a todo
#   things complete <ID>                      Mark todo complete
#   things cancel <ID>                        Mark todo cancelled
#   things delete <ID>                        Trash a todo
#
#   things search "query" [--limit N]         Search todos by name
#
#   things projects                           List all projects
#   things project show <name-or-id>          Show project + todos
#   things project add "name" [options]       Create a project
#   things project edit <name-or-id> [opts]   Update a project
#   things project complete <name-or-id>      Complete a project
#   things project delete <name-or-id>        Trash a project
#
#   things tags                               List all tags

require_relative "things"
require "json"
require "optparse"

def output(data)
  puts JSON.generate(data)
end

def success(data)
  output(ok: true, data: data)
  exit 0
end

def error(msg, code = "ERROR")
  output(ok: false, error: msg, code: code)
  exit 1
end

def parse_opts(args, *keys)
  opts = {}
  OptionParser.new do |o|
    o.on("--limit N", Integer) { |v| opts[:limit] = v } if keys.include?(:limit)
    o.on("--notes NOTES") { |v| opts[:notes] = v } if keys.include?(:notes)
    o.on("--when WHEN") { |v| opts[:when] = v } if keys.include?(:when)
    o.on("--deadline DATE") { |v| opts[:deadline] = v } if keys.include?(:deadline)
    o.on("--tags TAGS") { |v| opts[:tags] = v } if keys.include?(:tags)
    o.on("--project PROJECT") { |v| opts[:project] = v } if keys.include?(:project)
    o.on("--area AREA") { |v| opts[:area] = v } if keys.include?(:area)
    o.on("--name NAME") { |v| opts[:name] = v } if keys.include?(:name)
    o.on("--checklist ITEMS") { |v| opts[:checklist] = v } if keys.include?(:checklist)
  end.parse!(args)
  opts
end

begin
  t = Things.new
  command = ARGV.shift

  case command

  # ─── Lists ──────────────────────────────────────────────────────────────

  when "inbox", "today", "tomorrow", "upcoming", "anytime", "someday", "logbook"
    opts = parse_opts(ARGV, :limit)
    todos = t.list(command, limit: opts[:limit])
    success(todos: todos, total: todos.length)

  # ─── Todo CRUD ──────────────────────────────────────────────────────────

  when "add"
    title = ARGV.shift
    error("Missing title. Usage: things add \"title\" [--when today] [--deadline DATE] [--tags TAGS] [--project NAME] [--notes NOTES] [--checklist \"item1,item2\"]", "USAGE") unless title

    opts = parse_opts(ARGV, :notes, :when, :deadline, :tags, :project, :checklist)
    checklist = opts[:checklist]&.split(",")&.map(&:strip)

    result = t.create(title,
      notes: opts[:notes],
      when_: opts[:when],
      deadline: opts[:deadline],
      tags: opts[:tags],
      project: opts[:project],
      checklist: checklist
    )
    success(result)

  when "show"
    id = ARGV.shift
    error("Missing ID. Usage: things show <ID>", "USAGE") unless id
    todo = t.get(id)
    success(todo)

  when "edit"
    id = ARGV.shift
    error("Missing ID. Usage: things edit <ID> [--name NAME] [--notes NOTES] [--when WHEN] [--deadline DATE] [--tags TAGS] [--project NAME]", "USAGE") unless id

    opts = parse_opts(ARGV, :name, :notes, :when, :deadline, :tags, :project)
    error("No changes specified. Use --name, --notes, --when, --deadline, --tags, or --project", "USAGE") if opts.empty?

    t.update(id,
      name: opts[:name],
      notes: opts[:notes],
      when_: opts[:when],
      deadline: opts[:deadline],
      tags: opts[:tags],
      project: opts[:project]
    )
    success(updated: true, id: id)

  when "complete"
    id = ARGV.shift
    error("Missing ID. Usage: things complete <ID>", "USAGE") unless id
    t.complete(id)
    success(completed: true, id: id)

  when "cancel"
    id = ARGV.shift
    error("Missing ID. Usage: things cancel <ID>", "USAGE") unless id
    t.cancel_todo(id)
    success(cancelled: true, id: id)

  when "delete"
    id = ARGV.shift
    error("Missing ID. Usage: things delete <ID>", "USAGE") unless id
    t.delete_todo(id)
    success(deleted: true, id: id)

  # ─── Search ─────────────────────────────────────────────────────────────

  when "search"
    query = ARGV.shift
    error("Missing query. Usage: things search \"query\" [--limit N]", "USAGE") unless query
    opts = parse_opts(ARGV, :limit)
    todos = t.search(query, limit: opts[:limit])
    success(todos: todos, total: todos.length)

  # ─── Projects ───────────────────────────────────────────────────────────

  when "projects"
    projs = t.projects
    success(projects: projs, total: projs.length)

  when "project"
    subcmd = ARGV.shift

    case subcmd
    when "show"
      identifier = ARGV.shift
      error("Missing project name or ID. Usage: things project show <name-or-id>", "USAGE") unless identifier
      proj = t.project_show(identifier)
      success(proj)

    when "add"
      name = ARGV.shift
      error("Missing name. Usage: things project add \"name\" [--notes NOTES] [--area AREA] [--tags TAGS] [--when WHEN] [--deadline DATE]", "USAGE") unless name
      opts = parse_opts(ARGV, :notes, :area, :tags, :when, :deadline)
      result = t.create_project(name,
        notes: opts[:notes],
        area: opts[:area],
        tags: opts[:tags],
        when_: opts[:when],
        deadline: opts[:deadline]
      )
      success(result)

    when "edit"
      identifier = ARGV.shift
      error("Missing project name or ID. Usage: things project edit <name-or-id> [--name NAME] [--notes NOTES] [--tags TAGS] [--deadline DATE]", "USAGE") unless identifier
      opts = parse_opts(ARGV, :name, :notes, :tags, :deadline)
      error("No changes specified. Use --name, --notes, --tags, or --deadline", "USAGE") if opts.empty?
      t.update_project(identifier,
        name: opts[:name],
        notes: opts[:notes],
        tags: opts[:tags],
        deadline: opts[:deadline]
      )
      success(updated: true, identifier: identifier)

    when "complete"
      identifier = ARGV.shift
      error("Missing project name or ID. Usage: things project complete <name-or-id>", "USAGE") unless identifier
      t.complete_project(identifier)
      success(completed: true, identifier: identifier)

    when "delete"
      identifier = ARGV.shift
      error("Missing project name or ID. Usage: things project delete <name-or-id>", "USAGE") unless identifier
      t.delete_project(identifier)
      success(deleted: true, identifier: identifier)

    else
      error("Unknown project subcommand: #{subcmd}. Use: show, add, edit, complete, delete", "USAGE")
    end

  # ─── Tags ───────────────────────────────────────────────────────────────

  when "tags"
    tag_list = t.tags
    success(tags: tag_list, total: tag_list.length)

  # ─── Help ───────────────────────────────────────────────────────────────

  when nil, "help", "--help", "-h"
    puts <<~HELP
      Things CLI — CRUD for Things 3

      Lists:
        things inbox                              Show Inbox todos
        things today                              Show Today todos
        things upcoming                           Show Upcoming todos
        things anytime                            Show Anytime todos
        things someday                            Show Someday todos
        things logbook [--limit N]                Show completed todos

      Todos:
        things add "title" [options]              Create a todo
          --notes NOTES                             Add notes
          --when today|tomorrow|someday|anytime     Schedule it
          --deadline YYYY-MM-DD                     Set deadline
          --tags "Tag1,Tag2"                        Set tags
          --project "Project Name"                  Add to project
          --checklist "item1,item2,item3"            Add checklist items
        things show <ID>                          Show todo details
        things edit <ID> [options]                Update a todo
          --name, --notes, --when, --deadline, --tags, --project
        things complete <ID>                      Mark complete
        things cancel <ID>                        Mark cancelled
        things delete <ID>                        Move to Trash

      Search:
        things search "query" [--limit N]         Search todos by name

      Projects:
        things projects                           List all projects
        things project show <name-or-id>          Show project + its todos
        things project add "name" [options]       Create a project
          --notes, --area, --tags, --when, --deadline
        things project edit <name-or-id> [opts]   Update a project
          --name, --notes, --tags, --deadline
        things project complete <name-or-id>      Complete a project
        things project delete <name-or-id>        Trash a project

      Tags:
        things tags                               List all tags

      Notes:
        - All output is JSON to stdout
        - IDs are Things3 internal UUIDs (e.g., GNhFtoqboi9WGdx4bwPNcc)
        - Use --deadline none or --project none to clear those fields
    HELP
    exit 0

  else
    error("Unknown command: #{command}. Run 'things help' for usage.", "USAGE")
  end

rescue => e
  error(e.message)
end
