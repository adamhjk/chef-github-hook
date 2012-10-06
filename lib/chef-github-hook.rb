require 'sinatra'
require 'yajl'
require 'mixlib/shellout'
require 'chef'
require 'chef/node'

class ChefGithubHook
  class RestAPI < Sinatra::Base
    post '/' do
      push = Yajl::Parser.parse(params[:payload])
      ChefGithubHook.sync_to(push["after"])
    end
  end

  class << self
    def chef_repo_cmd(cmd)
      command = Mixlib::ShellOut.new("git checkout #{commit}")
      command.cwd(ENV["CHEF_REPO_DIR"])
      command.run_command
      command.error!
      return [ command.stdout, command.stderr ]
    end

    def parse_knife_diff_output(output)
      pending = {
        :cookbook_delete => [],
        :role_delete => [],
        :environment_delete => [],
        :data_bag_delete => []
      }
      output.each_line do |line|
        case line
        when /^D\s+cookbooks\/(.+)$/
          pending[:cookbook_delete] << $1
        when /^D\s+environments\/(.+)\.(json|rb)$/
          pending[:environment_delete] << $1
        when /^D\s+data_bags\/(.+)\/(.+)\.(json|rb)$/
          pending[:data_bag_delete] << "#{$1} #{$2}"
        when /^D\s+data_bags\/(.+)$/
          pending[:data_bag_delete] << $1
        when /^D\s+roles\/(.+)$/
          pending[:role_delete] << $1
        end
      end
    end

    def sync_nodes
      Chef::Config.from_file(File.join(ENV["CHEF_REPO_DIR"], ".chef", "knife.rb"))
      Chef::Node.list.each do |node_name|
        node = Chef::Node.load(node_name) 
        if File.exists?("#{ENV['CHEF_REPO_DIR']}/nodes/#{node_name}.rb")
          puts "  - Updating #{node_name}"
          node.instance_eval(IO.read("#{ENV['CHEF_REPO_DIR']}/nodes/#{node_name}.rb"))
        else
          puts "  - Deleting #{node_name}"
          node.destroy
        end
      end
    end

    def sync_to(commit)
      puts "* Pulling changes from origin master"
      chef_repo_cmd("git pull origin master")
      puts "* Checking out #{commit}"
      chef_repo_cmd("git checkout #{commit}")
      puts "* Checking for pending Chef objects to delete"
      pending_deletes = parse_knife_diff_output(chef_repo_cmd("knife diff --name-status")[0])
      puts "* Updating Chef Server"
      chef_repo_cmd("knife upload '*'")
      puts "* Deleting Cookbooks from Chef Server"
      pending_deletes[:cookbook_delete].each do |item|
        puts "  - deleting #{item}"
        chef_repo_cmd("knife cookbook delete #{item} -y -a")
      end
      puts "* Deleting Environments from Chef Server"
      pending_deletes[:environment_delete].each do |item|
        puts "  - deleting #{item}"
        chef_repo_cmd("knife environment delete #{item} -y")
      end
      puts "* Deleting Data Bag Items from Chef Server"
      pending_deletes[:data_bag_delete].each do |item|
        puts "  - deleting #{item}"
        chef_repo_cmd("knife data bag delete #{item} -y")
      end
      puts "* Deleting Roles from Chef Server"
      pending_deletes[:role_delete].each do |item|
        puts "  - deleting #{item}"
        chef_repo_cmd("knife role delete #{item} -y")
      end
      puts "* Updating Nodes"
      sync_nodes
      puts "* Victory is yours."
    end
  end
end
