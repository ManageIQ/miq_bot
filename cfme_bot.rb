#!/usr/bin/env ruby

require 'grit'
require 'timers'
require 'yaml'
SLEEPTIME = 180
PAGE_SIZE = 5
REPOSITORY_BASE = "/Users/bronaghsorota/dev/"

class Bot
  def initialize
    @repo_branches = { "cfme" =>['master', '5.1.0.x', '5.2.0.x'],
		       "cfme_tools" =>['master']}
    @last_fetch_times = Hash.new
    load_yaml_file
  end

  def get_commit_details
    @repo_branches.each do |repo_name, branches|
      repository = make_repo_path(repo_name)
      branches.each do |branch|
        page_start = 0
        complete = false
	make_repo_path(repo_name)

        repo = Grit::Repo.new(repository)
	Grit::Repo.new(repository).git.checkout
	Grit::Repo.new(repository).git.pull

	key = make_key(repo_name, branch)
        while !complete do 

	  # Get the list of commits on this repo and branch
	  # and pull out the bug ID, then update the ticket in 
	  # Bugzilla
	  # We need to get the results in pages, otherwise 
	  # the grit::commits method errors out

	  commits = repo.commits(branch, PAGE_SIZE, page_start )
	  complete = commits.empty?	  
	  commits.each do |commit| 
	    if commit.committed_date >= within_interval_range?(key)
	      puts #{key}
	      process_commit(commit)
	    else 
	      complete = true
	      break
	    end
	  end 
	  page_start += PAGE_SIZE
        end  
	add_and_yaml_timestamps(key)
      end  
    end 
    sleep(SLEEPTIME)
  end

  def process_commit(commit)
    print_commit(commit)
    match = commit.message.match(/(?<=Bug[\s.])[0-9]+/)
  end

  def print_commit(commit)
    puts "commit id:\t#{commit.id} \n"
    puts "committer:\t#{commit.committer}"
    puts "committed date:\t#{commit.committed_date}"
    puts "message:\t#{commit.message}"
    puts "\n"
    puts "\n"
  end
end

def within_interval_range?(key)
  @last_fetch_times[key] || Time.now - 600 
end

def make_key(repo_name, branch)
  "#{repo_name}-#{branch}"	
end

def make_repo_path(repo_name)
  File.join(REPOSITORY_BASE, repo_name)
end

def add_and_yaml_timestamps(key)
  @last_fetch_times[key] = Time.now
    File.open("cfme_bot.yml", 'w+') {|f| f.write(@last_fetch_times.to_yaml) }
end

def do_checkout_and_pull(repository, branch)
  puts %x{pwd}
  Dir.chdir(repository) do
    puts %x{pwd}
    puts %x{git checkout #{branch}}
    puts %x{git pull}
  end
  puts %x{pwd}
end

def load_yaml_file
  # We store the last time a branch was monitored for commits
  # We store this in a yaml file so should the BOT be restarted
  # we know exactly when to monitor a branch from

  times = YAML.load_file('cfme_bot.yml')
end

bot = Bot.new
loop {
  bot.get_commit_details
}

