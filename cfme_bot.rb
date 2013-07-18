#!/usr/bin/env ruby

require 'grit'
require 'timers'
require 'yaml'
SLEEPTIME = 180
PAGE_SIZE = 5
REPOSITORY_BASE = File.join(File.dirname(__FILE__), "..", "..") 

class Bot

  # OVERVIEW : Get the list of commits on each repo and branch
  # and pull out the bug ID, then update the ticket in 
  # Bugzilla


  def initialize

    @repo_branches = { "cfme" =>['master', '5.1.0.x', '5.2.0.x'],
            		       "cfme_tools" =>['master']}
    @last_fetch_times = Hash.new
    load_yaml_file
  end

  def update_code_get_commits
    @repo_branches.each do |repo_name, branches|
      repository_path = make_repo_path(repo_name)
      repo = Grit::Repo.new(repository_path)

      branches.each do |branch|
        page_start = 0
        key = make_key(repo_name, branch)
        
        repo.git.checkout
        repo.git.pull

        loop do 
          if !get_commits(repo, branch, key, page_start)
            break
          else
            page_start += PAGE_SIZE
          end
        end  
        add_and_yaml_timestamps(key)
      end  
      sleep(SLEEPTIME)
    end
  end

  def process_commit(commit)
    print_commit(commit)
    match = commit.message.match(/(?<=Bug[\s.])[0-9]+/)
  end

  def print_commit(commit)
    puts "commit id:\t#{commit.id} \n"
    puts "committer:\t#{commit.committer}"
    puts "author:\t#{commit.author}"
    puts "committed date:\t#{commit.committed_date}"
    puts "message:\t#{commit.message}"
    puts "\n"
    puts "\n"
  end

  def get_commits(repo, branch, key, page_start)
    # NOTE : We need to get the results in pages, otherwise 
    # the grit::commits method errors out.

    # page_start is initialized to 0 and increased by PAGE_SIZE
    # each time we move to a new page. This means the first page 
    # processed will be the first 5 commits (0-4 inclusive). 
    # The second page of commits will be the next 5 commits 
    # (5-9 inclusive) etc. Results are returned in chronological order so
    # as soon as we reach a commit that was made before time of the
    # last check we know we have captured all the relevant commits.

    commits = repo.commits(branch, PAGE_SIZE, page_start )
    complete = false

    # the complete variable indicates we have processed all
    # the commits for this time window, either none were 
    # returned or we have come across one that was already
    # processed.
   
    commits.each do |commit| 
      if commit.committed_date < within_interval_range?(key)
        complete
        break
      else 
        puts #{key}
        process_commit(commit)
        !complete
      end
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

    File.open("cfme_bot.yml", 'w+') do |f| 
      YAML.dump(@last_fetch_times, f) 
    end
  end

  def load_yaml_file
    # We store the last time a branch was monitored for commits
    # We store this in a yaml file so should the BOT be restarted
    # we know exactly when to monitor a branch from

    @last_fetch_times = YAML.load_file('cfme_bot.yml')
  end
end

bot = Bot.new
loop {
  bot.update_code_get_commits
}

