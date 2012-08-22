#!/usr/bin/env ruby

if RUBY_VERSION.match("1.8")
  require 'rubygems' 
  require 'ftools'
end
require 'micro-optparse'
require 'pathname'
require "fileutils"

#####################
### Options Parsing

@time = Time.now

options = Parser.new do |p|
  p.banner = "Mysql Backup Script"
  p.version = "1.0"
  p.option :verbose, "Enable verbose output", :default => false
  p.option :database, "Database to Backup", :default => ""
  p.option :append_name, "Name to Append to Database backup file", :default => ""
  p.option :dump_options, "Extra Dump Options for mysql_dump", :default => ""
  p.option :all, "Backup all databases? True or False", :default => false
  p.option :skip_tables, "Tables to Skip, comma separated", :default => []
  p.option :sql, "Custom SQL for mysql_dump", :default => ""
  p.option :rsa_password, "Password to Encrypt", :default => ""
  p.option :lzma_compression, "LZMA compress rate, default: 2", :default => '2'
  p.option :nice, "Nice level, default: 18 ", :default => '18'
  p.option :destination, "Absolute path for backup, default: /backup", :default => "/backup"
  p.option :db_password, "Mysql password, default: none", :default => ''
  p.option :db_username, "Mysql username, default: root", :default => ''
  p.option :dry_run, "Dry Run", :default => false
end.process!


unless !options[:database].empty? or options[:all]
  puts "  ERROR: Either --database or --all options are required, example: script.rb --database=mydb"
  exit
end

if !options[:skip_tables].empty? and options[:database].empty?
  puts "  ERROR: --skip_tables requires a database, example: script.rb --database=mydb --skip_tables=table1,table2"
  exit
end

if options[:verbose]
  @verb = true
else
  @verb = false
end

unless options[:skip_tables].empty?
  @skip_tables = []
  options[:skip_tables].each do |skip|
    @skip_tables << "--ignore-table=#{options[:database]}.#{skip}"
  end
  @skip_tables = @skip_tables.join(" ")
else
  @skip_tables = ""
end

@data_dir =  "#{options[:destination]}/backup/mysql/#{@time.strftime("%Y")}/#{@time.strftime("%m")}/#{@time.strftime("%d")}"
@filename = "#{@time.strftime("%Y%m%d_%H%M%S")}"


if @verb
  puts "Configuration:" 
  puts "  Backing up all databases: #{options[:all]}"
  puts "  Dump Options: #{options[:dump_options]}" unless options[:dump_options].empty?
  puts "  Append Name: #{options[:append_name]}" unless options[:append_name].empty?
  puts "  Database to Backup: #{options[:database]}" unless options[:database].empty?
  puts "  Skiping tables: #{options[:skip_tables].join(',')}" unless options[:skip_tables].empty?
  puts "  Custom SQL: #{options[:sql]}" unless options[:sql].empty?
  puts "  Mysql Username: #{options[:db_username]}"
  puts "  Mysql Password: #{options[:db_password]}"
  puts "  Encrypting with RSA: #{options[:rsa_password]}" unless options[:rsa_password].empty?
  puts "  LZMA level: #{options[:lzma_compression]}"
  puts "  Nice level: #{options[:nice]}"
  puts "  Destination: #{options[:destination]}"
  puts "  Final Path: #{@data_dir}"
  puts "  Final Filename: #{@filename}"
end


####################################################


def check_directories
  begin
    FileUtils.mkdir_p(@data_dir, :mode => 0700)
  rescue
    puts "Cannot create local directory #{@data_dir}"
    puts "Going to use '/tmp/#{@data_dir}' folder instead."
    @data_dir = "/tmp/#{@data_dir}"
  end
end


# Function to make the Database Dumps
def mysqldump(options)
  command = []
  command << "nice -n #{options[:nice]}"
  command << "mysqldump"
  command << "-u#{options[:db_username]}" unless options[:db_username].empty?
  command << "-p#{options[:db_password]}" unless options[:db_password].empty?
  command << options[:dump_options] unless options[:dump_options].empty?
  command << @skip_tables unless @skip_tables.empty?
  if options[:all]
    command << "--all-databases"
  else
    command << options[:database]
  end

  name = []
  name << "#{@data_dir}/#{options[:append_name]}"
  name << "all" if options[:all]
  name << options[:database] unless options[:database].empty?
  name << options[:dump_options].gsub("-","") unless options[:dump_options].empty?
  name << "no_#{options[:skip_tables].join('_')}" unless options[:skip_tables].empty?
  name << "#{@filename}.sql" 
  final_filename = name.join("_")

  puts "  Dumping to file: #{final_filename}" if @verb
  command << ">"
  command << final_filename
  command = command.join(" ")
  puts "  #{command}" if @verb
  system(command) unless options[:dry_run]
  return final_filename
end

# Compress method with LZMA
def compress_file(file_name, options)
  puts "  Compressing file #{file_name}" if @verb
  command = "nice -n #{options[:nice]} lzma -#{options[:lzma_compression]} -z #{file_name}"
  puts "  #{command}" if @verb
  system(command) unless options[:dry_run]
  return file_name+".lzma"
end

# Openssl encryption using Bluefish-CBC with Salt.
def encrypt_file(file_name, options)
  puts "  Encrypting file with RSA"
  command = "nice -n #{options[:nice]} openssl enc -bf-cbc -salt -in \"#{file_name}\" -out \"#{file_name}.enc\" -pass pass:#{options[:rsa_password]}"
  puts "  #{command}" if @verb
  system(command) unless options[:dry_run]
  FileUtils.rm_rf(file_name) unless options[:dry_run]
  return file_name+".enc"
end

@file_name = mysqldump(options)
@file_name = compress_file(@file_name,options)
unless options[:rsa_password].empty?
  @file_name = encrypt_file(@file_name,options)
end
