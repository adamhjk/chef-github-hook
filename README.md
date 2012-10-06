# Chef Github Hook

Will synchronize your chef-repo with a Chef Server. 

It assumes that all:

* Cookbooks
* Roles
* Nodes
* Data Bags
* Environments

Are controlled via git. Anything not in your repo will be deleted.

# Start the service

You can start the service with:

    env CHEF_REPO_DIR=YOUR_CHEF_REPO_PATH ./bin/chef-github-hook 

Replace YOUR_CHEF_REPO_PATH with, um.. the path to the chef
repo you want to manage. Assumes you have a working .chef/knife.rb
file inside that repository.

# When github sends you a message..

We will pull the updates from github, checkout the "after"
commit in the payload, and synchronize the above.

# How does this work for nodes?

We load every node in a loop. If a file exists that is the node
name ending with ".rb", we will instance-eval that file in the
context of the node we fetched.

# How ready is this code?

Not at all. I've actually never even run it. Pretty sure it'll
almost work, though.

# Is this officially supported by Opscode?

Not at all.

# License

See the LICENSE file - Apache 2. Copyright Adam Jacob. 
