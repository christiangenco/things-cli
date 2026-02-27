# Things3 AppleScript wrapper
#
# Provides full CRUD for todos and projects via osascript.
# All methods return Ruby hashes/arrays. Raises on AppleScript errors.

require "json"
require "open3"
require "date"

class Things
  LISTS = %w[Inbox Today Tomorrow Anytime Upcoming Someday Logbook Trash].freeze
  DELIMITER = "|||"
  ROW_DELIMITER = "~~~"

  # ─── Todos: Read ──────────────────────────────────────────────────────────

  def list(name, limit: nil)
    raise "Unknown list: #{name}" unless LISTS.any? { |l| l.downcase == name.downcase }
    canonical = LISTS.find { |l| l.downcase == name.downcase }

    script = <<~AS
      tell application "Things3"
        set output to ""
        set todoList to to dos of list "#{canonical}"
        #{limit ? "set maxItems to #{limit.to_i}" : "set maxItems to count of todoList"}
        set counter to 0
        repeat with t in todoList
          set counter to counter + 1
          if counter > maxItems then exit repeat
          if counter > 1 then set output to output & "#{ROW_DELIMITER}"
          set output to output & id of t & "#{DELIMITER}"
          set output to output & name of t & "#{DELIMITER}"
          set output to output & status of t & "#{DELIMITER}"
          set output to output & tag names of t & "#{DELIMITER}"
          set output to output & due date of t & "#{DELIMITER}"
          set output to output & activation date of t & "#{DELIMITER}"
          set output to output & notes of t & "#{DELIMITER}"
          try
            set output to output & name of project of t
          on error
            set output to output & ""
          end try
          set output to output & "#{DELIMITER}"
          try
            set output to output & name of area of t
          on error
            set output to output & ""
          end try
        end repeat
        return output
      end tell
    AS

    raw = run_applescript(script)
    todos = parse_todo_rows(raw)
    # Filter out blank-name todos (e.g., time-block project placeholders)
    todos.reject { |t| t[:name].nil? || t[:name].strip.empty? }
  end

  def get(id)
    script = <<~AS
      tell application "Things3"
        set t to to do id "#{escape(id)}"
        set output to id of t & "#{DELIMITER}"
        set output to output & name of t & "#{DELIMITER}"
        set output to output & status of t & "#{DELIMITER}"
        set output to output & tag names of t & "#{DELIMITER}"
        set output to output & due date of t & "#{DELIMITER}"
        set output to output & activation date of t & "#{DELIMITER}"
        set output to output & notes of t & "#{DELIMITER}"
        try
          set output to output & name of project of t
        on error
          set output to output & ""
        end try
        set output to output & "#{DELIMITER}"
        try
          set output to output & name of area of t
        on error
          set output to output & ""
        end try
        set output to output & "#{DELIMITER}"
        set output to output & creation date of t & "#{DELIMITER}"
        set output to output & modification date of t & "#{DELIMITER}"
        set output to output & completion date of t & "#{DELIMITER}"
        set output to output & cancellation date of t
        return output
      end tell
    AS

    raw = run_applescript(script)
    parse_todo_detail(raw)
  end

  def search(query, limit: nil)
    max = limit || 50
    script = <<~AS
      tell application "Things3"
        set output to ""
        set results to (to dos whose name contains "#{escape(query)}" and status is open)
        set maxItems to #{max.to_i}
        set counter to 0
        repeat with t in results
          set counter to counter + 1
          if counter > maxItems then exit repeat
          if counter > 1 then set output to output & "#{ROW_DELIMITER}"
          set output to output & id of t & "#{DELIMITER}"
          set output to output & name of t & "#{DELIMITER}"
          set output to output & status of t & "#{DELIMITER}"
          set output to output & tag names of t & "#{DELIMITER}"
          set output to output & due date of t & "#{DELIMITER}"
          set output to output & activation date of t & "#{DELIMITER}"
          set output to output & notes of t & "#{DELIMITER}"
          try
            set output to output & name of project of t
          on error
            set output to output & ""
          end try
          set output to output & "#{DELIMITER}"
          try
            set output to output & name of area of t
          on error
            set output to output & ""
          end try
        end repeat
        return output
      end tell
    AS

    raw = run_applescript(script)
    parse_todo_rows(raw)
  end

  # ─── Todos: Create ────────────────────────────────────────────────────────

  def create(title, notes: nil, when_: nil, deadline: nil, tags: nil, project: nil, checklist: nil)
    props = ["name:\"#{escape(title)}\""]
    props << "notes:\"#{escape(notes)}\"" if notes

    if deadline
      props << "due date:date \"#{format_date(deadline)}\""
    end

    if tags
      props << "tag names:\"#{escape(tags)}\""
    end

    create_line = "set newTodo to make new to do with properties {#{props.join(', ')}}"

    lines = ["tell application \"Things3\""]
    lines << "  #{create_line}"

    if project
      lines << "  set proj to first project whose name is \"#{escape(project)}\""
      lines << "  set project of newTodo to proj"
    end

    if checklist && !checklist.empty?
      checklist.each_with_index do |item, i|
        lines << "  tell newTodo"
        lines << "    make new checklist item with properties {name:\"#{escape(item)}\"}"
        lines << "  end tell"
      end
    end

    case when_&.downcase
    when "today"
      lines << "  move newTodo to list \"Today\""
    when "tomorrow"
      lines << "  move newTodo to list \"Tomorrow\""
    when "someday"
      lines << "  move newTodo to list \"Someday\""
    when "anytime"
      lines << "  move newTodo to list \"Anytime\""
    when nil
      # Inbox by default
    else
      # Try as a date
      lines << "  set startDate to date \"#{format_date(when_)}\""
      lines << "  move newTodo to list \"Anytime\""
      lines << "  set activation date of newTodo to startDate"
    end

    lines << "  return id of newTodo"
    lines << "end tell"

    id = run_applescript(lines.join("\n")).strip
    { id: id, name: title }
  end

  # ─── Todos: Update ────────────────────────────────────────────────────────

  def update(id, name: nil, notes: nil, when_: nil, deadline: nil, tags: nil, project: nil)
    lines = ["tell application \"Things3\""]
    lines << "  set t to to do id \"#{escape(id)}\""

    lines << "  set name of t to \"#{escape(name)}\"" if name
    lines << "  set notes of t to \"#{escape(notes)}\"" if notes
    lines << "  set tag names of t to \"#{escape(tags)}\"" if tags

    if deadline == "none"
      lines << "  set due date of t to missing value"
    elsif deadline
      lines << "  set due date of t to date \"#{format_date(deadline)}\""
    end

    if project == "none"
      lines << "  set project of t to missing value"
    elsif project
      lines << "  set proj to first project whose name is \"#{escape(project)}\""
      lines << "  set project of t to proj"
    end

    case when_&.downcase
    when "today"
      lines << "  move t to list \"Today\""
    when "tomorrow"
      lines << "  move t to list \"Tomorrow\""
    when "someday"
      lines << "  move t to list \"Someday\""
    when "anytime"
      lines << "  move t to list \"Anytime\""
    when "inbox"
      lines << "  move t to list \"Inbox\""
    when nil
      # no change
    end

    lines << "  return name of t"
    lines << "end tell"

    run_applescript(lines.join("\n"))
    true
  end

  def complete(id)
    run_applescript(%(tell application "Things3" to set status of to do id "#{escape(id)}" to completed))
    true
  end

  def cancel_todo(id)
    run_applescript(%(tell application "Things3" to set status of to do id "#{escape(id)}" to canceled))
    true
  end

  def delete_todo(id)
    run_applescript(%(tell application "Things3" to delete to do id "#{escape(id)}"))
    true
  end

  # ─── Projects ─────────────────────────────────────────────────────────────

  def projects
    script = <<~AS
      tell application "Things3"
        set output to ""
        set counter to 0
        repeat with p in every project
          set counter to counter + 1
          if counter > 1 then set output to output & "#{ROW_DELIMITER}"
          set output to output & id of p & "#{DELIMITER}"
          set output to output & name of p & "#{DELIMITER}"
          set output to output & status of p & "#{DELIMITER}"
          try
            set output to output & name of area of p
          on error
            set output to output & ""
          end try
          set output to output & "#{DELIMITER}"
          set output to output & (count of to dos of p)
        end repeat
        return output
      end tell
    AS

    raw = run_applescript(script)
    return [] if raw.strip.empty?

    raw.split(ROW_DELIMITER).map do |row|
      fields = row.split(DELIMITER, -1)
      {
        id: fields[0],
        name: fields[1],
        status: fields[2],
        area: blank(fields[3]),
        todo_count: fields[4]&.to_i
      }
    end
  end

  def project_show(identifier)
    # Try by ID first, fall back to name
    script = <<~AS
      tell application "Things3"
        try
          set p to project id "#{escape(identifier)}"
        on error
          set p to first project whose name is "#{escape(identifier)}"
        end try
        set output to id of p & "#{DELIMITER}"
        set output to output & name of p & "#{DELIMITER}"
        set output to output & status of p & "#{DELIMITER}"
        try
          set output to output & name of area of p
        on error
          set output to output & ""
        end try
        set output to output & "#{DELIMITER}"
        set output to output & notes of p & "#{DELIMITER}"
        set output to output & creation date of p & "#{DELIMITER}"
        set output to output & modification date of p

        set output to output & "#{ROW_DELIMITER}"

        set counter to 0
        repeat with t in to dos of p
          set counter to counter + 1
          if counter > 1 then set output to output & "#{ROW_DELIMITER}"
          set output to output & id of t & "#{DELIMITER}"
          set output to output & name of t & "#{DELIMITER}"
          set output to output & status of t & "#{DELIMITER}"
          set output to output & tag names of t & "#{DELIMITER}"
          set output to output & due date of t
        end repeat

        return output
      end tell
    AS

    raw = run_applescript(script)
    rows = raw.split(ROW_DELIMITER)
    proj_fields = rows[0].split(DELIMITER, -1)

    todos = rows[1..].map do |row|
      fields = row.split(DELIMITER, -1)
      next if fields[0].to_s.strip.empty?
      {
        id: fields[0],
        name: fields[1],
        status: fields[2],
        tags: blank(fields[3]),
        deadline: clean_date(fields[4])
      }
    end.compact

    {
      id: proj_fields[0],
      name: proj_fields[1],
      status: proj_fields[2],
      area: blank(proj_fields[3]),
      notes: blank(proj_fields[4]),
      created: proj_fields[5],
      modified: proj_fields[6],
      todos: todos
    }
  end

  def create_project(name, notes: nil, area: nil, tags: nil, when_: nil, deadline: nil)
    props = ["name:\"#{escape(name)}\""]
    props << "notes:\"#{escape(notes)}\"" if notes
    props << "tag names:\"#{escape(tags)}\"" if tags
    props << "due date:date \"#{format_date(deadline)}\"" if deadline

    lines = ["tell application \"Things3\""]
    lines << "  set newProj to make new project with properties {#{props.join(', ')}}"

    if area
      lines << "  set a to first area whose name is \"#{escape(area)}\""
      lines << "  set area of newProj to a"
    end

    case when_&.downcase
    when "today"
      lines << "  move newProj to list \"Today\""
    when "someday"
      lines << "  move newProj to list \"Someday\""
    when "anytime"
      lines << "  move newProj to list \"Anytime\""
    end

    lines << "  return id of newProj"
    lines << "end tell"

    id = run_applescript(lines.join("\n")).strip
    { id: id, name: name }
  end

  def update_project(identifier, name: nil, notes: nil, tags: nil, deadline: nil)
    lines = ["tell application \"Things3\""]
    lines << "  try"
    lines << "    set p to project id \"#{escape(identifier)}\""
    lines << "  on error"
    lines << "    set p to first project whose name is \"#{escape(identifier)}\""
    lines << "  end try"

    lines << "  set name of p to \"#{escape(name)}\"" if name
    lines << "  set notes of p to \"#{escape(notes)}\"" if notes
    lines << "  set tag names of p to \"#{escape(tags)}\"" if tags

    if deadline == "none"
      lines << "  set due date of p to missing value"
    elsif deadline
      lines << "  set due date of p to date \"#{format_date(deadline)}\""
    end

    lines << "  return name of p"
    lines << "end tell"

    run_applescript(lines.join("\n"))
    true
  end

  def complete_project(identifier)
    script = <<~AS
      tell application "Things3"
        try
          set p to project id "#{escape(identifier)}"
        on error
          set p to first project whose name is "#{escape(identifier)}"
        end try
        set status of p to completed
      end tell
    AS
    run_applescript(script)
    true
  end

  def delete_project(identifier)
    script = <<~AS
      tell application "Things3"
        try
          set p to project id "#{escape(identifier)}"
        on error
          set p to first project whose name is "#{escape(identifier)}"
        end try
        delete p
      end tell
    AS
    run_applescript(script)
    true
  end

  # ─── Tags ─────────────────────────────────────────────────────────────────

  def tags
    script = <<~AS
      tell application "Things3"
        set output to ""
        set counter to 0
        repeat with t in every tag
          set counter to counter + 1
          if counter > 1 then set output to output & "#{ROW_DELIMITER}"
          set output to output & name of t
        end repeat
        return output
      end tell
    AS

    raw = run_applescript(script)
    return [] if raw.strip.empty?
    raw.split(ROW_DELIMITER).map(&:strip)
  end

  private

  def run_applescript(script)
    stdout, stderr, status = Open3.capture3("osascript", "-e", script)
    unless status.success?
      msg = stderr.strip
      # Friendlier error messages
      if msg.include?("get to do id")
        raise "Todo not found"
      elsif msg.include?("get project id") || msg.include?("get project whose")
        raise "Project not found"
      else
        raise "AppleScript error: #{msg}"
      end
    end
    stdout.strip
  end

  def escape(str)
    return "" if str.nil?
    str.to_s.gsub('\\', '\\\\\\\\').gsub('"', '\\"')
  end

  def format_date(str)
    return str if str.nil?
    # Accept YYYY-MM-DD and convert to AppleScript-friendly format
    if str =~ /^\d{4}-\d{2}-\d{2}$/
      d = Date.parse(str)
      d.strftime("%B %d, %Y")
    else
      str
    end
  end

  def clean_date(val)
    return nil if val.nil? || val.strip.empty? || val.include?("missing value")
    s = val.strip
    # Convert verbose AppleScript dates like "Thursday, February 26, 2026 at 12:00:00 AM" to ISO 8601
    begin
      d = DateTime.parse(s)
      if d.hour == 0 && d.min == 0 && d.sec == 0
        d.strftime("%Y-%m-%d")
      else
        d.strftime("%Y-%m-%dT%H:%M:%S")
      end
    rescue ArgumentError
      s
    end
  end

  def blank(val)
    return nil if val.nil? || val.strip.empty?
    val.strip
  end

  def parse_todo_rows(raw)
    return [] if raw.strip.empty?

    raw.split(ROW_DELIMITER).map do |row|
      fields = row.split(DELIMITER, -1)
      {
        id: fields[0],
        name: fields[1],
        status: fields[2],
        tags: blank(fields[3]),
        deadline: clean_date(fields[4]),
        start_date: clean_date(fields[5]),
        notes: blank(fields[6]),
        project: blank(fields[7]),
        area: blank(fields[8])
      }
    end
  end

  def parse_todo_detail(raw)
    fields = raw.split(DELIMITER, -1)
    {
      id: fields[0],
      name: fields[1],
      status: fields[2],
      tags: blank(fields[3]),
      deadline: clean_date(fields[4]),
      start_date: clean_date(fields[5]),
      notes: blank(fields[6]),
      project: blank(fields[7]),
      area: blank(fields[8]),
      created: fields[9],
      modified: fields[10],
      completed: clean_date(fields[11]),
      cancelled: clean_date(fields[12])
    }
  end
end
