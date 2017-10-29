require 'fileutils'
require_relative './lib/sql_runner'
require_relative './lib/backup_helper'
require_relative './lib/database_logger'

class BackUpManager
  DIVIDER = "--------------------------------------------------"
  def initialize(database_name, backup_dir)
    @database_name = database_name
    @backup_dir = backup_dir
  end

  def run()
    ## set the time interval between new backups
    # restore a selected database
    # set the max space to use up / max number of backups to make
    run = true
    while(run)
      puts DIVIDER
      puts_manager_intro()

      input = get_user_input(["1", "2", "3"]) do
        puts "1) Restore a backup\n"+
            "2) Change how many backup to store before deleting old ones\n" +
            "3) Exit"
      end

      case input
        when "1"
          run_restore_backup_menu()
        when "2"
          run_change_storage()
        when "3"
          run = false
      end
    end
    puts "Exit"
  end

  private

  def get_user_input(options, &call_back)
    input = nil
    valid_input = false
    while(!valid_input)
      call_back.call()
      input = gets.chomp
      valid_input = is_input_valid?(input, options)
      puts DIVIDER
    end
    return input
  end

  def puts_manager_intro()
    puts "Welcome to the backup managaer."
    puts "What would you like to do"
  end

  def run_restore_backup_menu()
    files = get_backup_file_list()

    input_options = []
    for index in (0..files.count())
      input_options.push((index+1).to_s)
    end

    input = get_user_input(input_options) do
      puts "Please select which file you would like to use to restore the database"
      files.each_with_index do |file, index|
        puts "#{(index+1).to_s}) #{file}"
      end
      puts "#{input_options[-1]}) Back"
    end
    selected_file = files[(input.to_i)-1]

    if(input != input_options[-1])
      question = "Restoring #{selected_file} will override the current" +
      "database with this (a backup of the current state will also be made)"
      if(confirm_input(question))
        restore_from_file(selected_file)
      end
    end
  end

  def run_change_storage()
    puts "run_change_storage"
  end

  def is_input_valid?(input, options)
    result = options.include?(input)
    if(!result)
      to_output = options.join(", ")
      puts "Error please enter: #{to_output}"
    end
    return result
  end

  def get_backup_file_list()
    return Dir["#{@backup_dir}*"].map do |file|
      file.split("/")[-1]
    end
  end

  def confirm_input(question)
    puts question
    puts "Are you sure?"
    input = get_user_input(["1", "2"]) do
      puts "1) yes\n2) no"
    end
    return input == "1"
  end

  def restore_from_file(file)
    backup_helper = BackUpHelper.new(@backup_dir)
    system("pg_dump #{@database_name} | gzip > #{backup_helper.get_backup_file_name()}.gz")
    log_database("#{backup_helper.get_log_file_name}.txt")
    delete_all_data()
    system("gunzip -c #{@backup_dir}#{file}/#{file}.gz | psql #{@database_name}")
  end

  def delete_all_data()
    tables = SqlRunner.run("SELECT tablename FROM pg_catalog.pg_tables WHERE schemaname = 'public';")
    table_data = tables.map do |table|
      command = "DROP TABLE #{table["tablename"]}"
      puts command
      count = SqlRunner.run(command)
    end
  end
end

BackUpManager.new("givingweb_api_development" ,"./db/backup/").run()
