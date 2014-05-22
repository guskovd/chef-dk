#
# Copyright:: Copyright (c) 2014 Chef Software Inc.
# License:: Apache License, Version 2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

require 'spec_helper'
require 'shared/setup_git_cookbooks'
require 'fileutils'
require 'chef-dk/helpers'
require 'chef-dk/cookbook_profiler/git'

describe ChefDK::CookbookProfiler::Git do

  include ChefDK::Helpers

  include_context "setup git cookbooks"

  let(:git_profiler) do
    ChefDK::CookbookProfiler::Git.new(cookbook_path)
  end

  def edit_repo
    File.open(File.join(cookbook_path, "README.md"), "a+") { |f| f.puts "some unpublished changes" }
  end

  context "given a clean repo with no remotes" do

    it "reports that the repo has no remotes" do
      expect(git_profiler.remote).to be_nil
    end

    it "determines the rev of the repo" do
      expect(git_profiler.revision).to eq(current_rev)
    end

    it "reports that the repo is clean" do
      expect(git_profiler.clean?).to be_true
    end

    it "reports that the commits are unpublished" do
      expect(git_profiler.unpublished_commits?).to be_true
    end

    it "reports that no remotes have the commits" do
      expect(git_profiler.synchronized_remotes).to eq([])
    end

  end

  context "with a remote configured" do
    let(:remote_url) { "file://#{tempdir}/bar-cookbook.git" }

    before do
      system_command("git init --bare #{tempdir}/bar-cookbook.git")
      system_command("git remote add origin #{remote_url}", cwd: cookbook_path)
      system_command("git push -u origin master", cwd: cookbook_path)
    end

    context "given a clean repo with all commits published to the remote" do

      it "determines the remote for the repo" do
        expect(git_profiler.remote).to eq(remote_url)
      end

      it "determines the rev of the repo" do
        expect(git_profiler.revision).to eq(current_rev)
      end

      it "reports that the repo is clean" do
        expect(git_profiler.clean?).to be_true
      end

      it "reports that all commits are published to the upstream" do
        expect(git_profiler.unpublished_commits?).to be_false
      end

      it "lists the remotes that commits are published to" do
        expect(git_profiler.synchronized_remotes).to eq(%w[origin/master])
      end

    end

    context "given a clean repo with unpublished changes" do

      before do
        edit_repo
        system_command("git commit -a -m 'update readme'", cwd: cookbook_path)
      end

      it "reports that the repo is clean" do
        expect(git_profiler.clean?).to be_true
      end

      it "reports that there are unpublished changes" do
        expect(git_profiler.unpublished_commits?).to be_true
      end

      it "reports that no remotes have the commits" do
        expect(git_profiler.synchronized_remotes).to eq([])
      end

    end
  end

  context "given a dirty repo" do

    before do
      edit_repo
    end

    it "reports that the repo is dirty" do
      expect(git_profiler.clean?).to be_false
    end

  end

end

