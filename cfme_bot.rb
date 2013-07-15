#!/usr/bin/env ruby

require 'grit'
require 'timers'
INTERVAL = 300
PAGE_SIZE = 3
REPOSITORY_BASE = "/Users/mysorota/dev/"

class Bot
  def initialize
    @repo_branches = { "cfme" =>['master', '5.1.0.x', '5.2.0.x']}
		       #"cfme_tools" =>['master']}
    @last_fetch_times = Hash.new
  end

  def get_commit_details
    @repo_branches.each do |repository_name, branches|
      repository = "#{REPOSITORY_BASE}" "#{repository_name}"
      branches.each do |branch|

        puts "REPO: #{repository_name}"
	puts "BRANCH: #{branch}"
        page_start = 0
        complete = :false

        repo = Grit::Repo.new(repository)
	do_checkout_and_pull(repository, branch)
	key = "#{repository_name} - #{branch}"

        while complete == :false do 
          puts "START POINT #{page_start}"
	  commits = repo.commits(branch, PAGE_SIZE, page_start )
	  if commits.empty?
	    complete = :true
	  end
	  puts "TOTAL PAGE COMMITS #{commits.count}"
	  commits.each do |commit| 
	    puts "COMMIT DATE #{commit.committed_date}"
	    puts "Last fetch time: #{within_interval_range?(key)}"

	    if commit.committed_date >=within_interval_range?(key)
	      print_commit(commit)
	      match = commit.message.match(/(?<=Bug[\s.])[0-9]+/)
	      if match
	        puts "BUG ID #{match[0]}"
	      end
	    else 
	      puts "COMMIT OUTSIDE WINDOW. BAILING ON THIS PAGE"
	      complete= :true
	      break
	    end # end of if
	  end #end of looping through this page of commits
	  puts "\n\n"
	  page_start +=PAGE_SIZE
        end   #end of while loop
	@last_fetch_times[key]= Time.now
	puts "Last fetch times:  #{@last_fetch_times.inspect}"
      end  # end of looping through branches
    end # end of looping through repos

    sleep(180)
  end

  def print_commit(commit)
    puts "commit id:\t#{commit.id} \n"
    puts "commit author:\t#{commit.author}"
    puts "authored date:\t #{commit.authored_date}"
    puts "committer:\t#{commit.committer}"
    puts "committed date:\t#{commit.committed_date}"
    puts "message:\t#{commit.message}"
    puts "\n"
  end
end

def within_interval_range?(key)
  if @last_fetch_times.include?(key) == false
    last_fetch_time = Time.now() - 600
  else
    last_fetch_time = @last_fetch_times[key]
  end
  #return last_fetch_time
end

def do_checkout_and_pull(repository, branch)

  puts "#{%x'pwd'}"

  Dir.chdir(repository){
    puts "#{%x'pwd'}"
    puts "#{%x"git checkout #{branch}"}"
    puts "#{%x'git pull'}"
  }
  puts "#{%x'pwd'}"
end

bot = Bot.new

loop {
  bot.get_commit_details
}



	#commit_list = repo.git.rev_list({:pretty => "raw", :since=>'2013-06-24 15:25:55'}, 'master') #Get a stack eror on this even with the since parameter set.
	#commits = Grit::Commit.list_from_string(repo, commit_list)

	
	#commits = repo.commits_since(branch, @fetch_from_time) #THIS DOESNT WORK ON CFME
        #commits = repo.commits(branch)   #THIS WORKS ON CFME, GRABS ALL

        #repo.git.native :checkout, {}, branch
	#      repo.git.native(:checkout, {}, branch)
        #repo.git.native(:pull, {})
