require 'test_helper'

class WebhooksControllerTest < ActionController::TestCase
  let(:tracked_branch) { FactoryGirl.create(:tracked_branch) }
  let(:project) { tracked_branch.project }
  let(:user) { project.user }
  let(:commit_sha) { "HEAD" }
  let(:filename_1) { "test/models/user_test.rb" }
  let(:filename_2) { "test/models/hello_test.rb" }

  describe "POST#github" do
    describe "when request is verified" do
      before do
        project.update_column(:repository_provider, 'github')
        # Successful authorization for GitHub
        @controller.stubs(:verify_request_from_github!).returns(nil)
      end

      describe "delete event" do
        before do
          request.headers['HTTP_X_GITHUB_EVENT'] = 'delete'
          GithubRepositoryManager.any_instance.stubs(:project_file_names).
            returns([filename_1, filename_2])
          post :github,
            params: { repository: { id: project.repository_id },
                      ref_type: 'branch',
                      ref: "#{tracked_branch.branch_name}" }
        end

        it "destroys the branch" do
          TrackedBranch.count.must_equal 0
        end
      end

      describe "push event" do
        let(:github_response) do
          Sawyer::Resource.new(Sawyer::Agent.new('api.example.com'),
            {
              sha: commit_sha,
              commit: {
                message: 'Some commit messsage',
                html_url: 'Some url',
                author: {
                  name: 'Great Author',
                  email: 'great@author.com',
                },
                committer: {
                  name: 'Great Committer',
                  email: 'great@committer.com',
                  date: Date.current.to_s,
                  avatar_url: 'http://dummy.url'
                }
              },
              author: { login: 'authorlogin' },
              committer: {
                login: 'committerlogin',
                avatar_url: 'http://dummy.url'
              }
            }
          )
        end

        let(:github_params) do
          {
            head_commit: {
              id: commit_sha,
              message: 'Some commit messsage',
              url: 'Some url',
              author: {
                name: 'Great Author',
                email: 'great@author.com',
                username: 'authorusername'
              },
              committer: {
                name: 'Great Committer',
                email: 'great@committer.com',
                username: 'committerusername',
                avatar_url: 'http://dummy.url'
              }
            },
            repository: { id: project.repository_id },
            ref: "refs/head/ispyropoulos/#{tracked_branch.branch_name}"
          }
        end

        before do
          request.headers['HTTP_X_GITHUB_EVENT'] = 'push'
          GithubRepositoryManager.any_instance.stubs(:sha_history).
            returns([github_response])

          GithubRepositoryManager.any_instance.stubs(:project_file_names).
            returns([filename_1, filename_2])
        end

        describe "auto-track branch" do
          it "creates a branch when it doesn't exist and project.auto_track_branches == true" do
            project.update_column(:auto_track_branches, true)
            new_branch_name = "a_new_branch"
            github_params[:ref] = "refs/head/ispyropoulos/#{new_branch_name}"
            post :github, params: github_params

            branch = TrackedBranch.last
            branch.project.must_equal project
            branch.branch_name.must_equal new_branch_name
            project.tracked_branches.count.must_equal 2
          end

          it "doesn't create a branch when it doesn't exist and project.auto_track_branches == false" do
            project.update_column(:auto_track_branches, false)
            new_branch_name = "a_new_branch"
            github_params[:ref] = "refs/head/ispyropoulos/#{new_branch_name}"
            post :github, params: github_params

            branch = TrackedBranch.last
            branch.project.must_equal project
            branch.branch_name.wont_equal new_branch_name
            project.tracked_branches.count.must_equal 1
          end
        end

        it "creates a test run with correct attributes" do
          post :github, params: github_params

          testrun = TestRun.last
          testrun.tracked_branch_id.must_equal tracked_branch.id
          testrun.commit_sha.must_equal commit_sha
          testrun.status.code.must_equal TestStatus::SETUP
        end

        it "responds with :ok" do
          post :github, params: github_params

          assert_response :ok
        end
      end
    end

    describe "when request is unverified" do
      before do
        ENV['GITHUB_WEBHOOK_SECRET'] = 'our little secret'
        request.headers['HTTP_X_HUB_SIGNATURE'] = 'rogue signature'
      end

      after do
        ENV['GITHUB_WEBHOOK_SECRET'] = nil
      end

      describe "delete event" do
        before do
          request.headers['HTTP_X_GITHUB_EVENT'] = 'delete'
          post :github
        end

        it "responds with :unauthorized" do
          assert_response :unauthorized
        end
      end

      describe "delete push" do
        before do
          request.headers['HTTP_X_GITHUB_EVENT'] = 'push'
          post :github
        end

        it "responds with :unauthorized" do
          assert_response :unauthorized
        end
      end
    end
  end

  describe "POST#bitbucket" do
    before do
      project.update_columns({
        repository_provider: 'bitbucket',
        repository_slug: project.repository_name.downcase,
      })
    end

    describe "push event" do
      let(:bitbucket_response) do
        [
          Hashie::Mash.new({
            hash: commit_sha,
            message: "Move directory depth to env var",
            date: "2016-03-21T16:05:37+00:00",
            links: Hashie::Mash.new({
              html: Hashie::Mash.new({
                href: "https://bitbucket.org/ispyropoulos/katana/commits/8559bdcb5969ae5b703c7c054c8126d64e6ebd76"
              })
            }),
            author: Hashie::Mash.new({
              raw: "Dimitris Karakasilis <jimmykarily@gmail.com>",
              user: Hashie::Mash.new({
                username: "jimmykarily",
                display_name: "Jimmy Karily",
                links: {
                  avatar: {
                    href: "http://dummy.url"
                  }
                }
              })
            })
          })
        ]
      end

      let(:bitbucket_params) do
        {
          push: {
            changes:
              [
                {
                  new: {
                    name: tracked_branch.branch_name,
                    target: {
                      hash: commit_sha,
                      message: "Move directory depth to env var",
                      date: "2016-03-21T16:05:37+00:00",
                      links: {
                        html: {
                          href: "https://bitbucket.org/ispyropoulos/katana/commits/8559bdcb5969ae5b703c7c054c8126d64e6ebd76"
                        }
                      },
                      author: Hashie::Mash.new({
                        raw: "Dimitris Karakasilis <jimmykarily@gmail.com>",
                        user: Hashie::Mash.new({
                          username: "jimmykarily",
                          display_name: "Jimmy Karily",
                          links: {
                            avatar: {
                              href: "http://dummy.url"
                            }
                          }
                        })
                      })
                    }
                  }
                }
              ]
          }
        }
      end

      before do
        request.headers['X-Event-Key'] = 'repo:push'
        BitbucketRepositoryManager.any_instance.stubs(:sha_history).
          returns(bitbucket_response)

        BitbucketRepositoryManager.any_instance.stubs(:project_file_names).
          returns([filename_1, filename_2])


      end

      describe "auto-track branch" do
        it "creates a branch when it doesn't exist and project.auto_track_branches == true" do
          project.update_column(:auto_track_branches, true)
          new_branch_name = "a_new_branch"
          bitbucket_params[:push][:changes].first[:new][:name] = new_branch_name
          post :bitbucket, params: {
            repository: {
              name: project.repository_slug
            }
          }.merge(bitbucket_params)

          branch = TrackedBranch.last
          branch.project.must_equal project
          branch.branch_name.must_equal new_branch_name
          project.tracked_branches.count.must_equal 2
        end

        it "doesn't create a branch when it doesn't exist and project.auto_track_branches == false" do
          project.update_column(:auto_track_branches, false)
          new_branch_name = "a_new_branch"
          bitbucket_params[:push][:changes].first[:new][:name] = new_branch_name
          post :bitbucket, params: {
            repository: {
              name: project.repository_slug
            }
          }.merge(bitbucket_params)

          branch = TrackedBranch.last
          branch.project.must_equal project
          branch.branch_name.wont_equal new_branch_name
          project.tracked_branches.count.must_equal 1
        end
      end

      it "creates a test run with correct attributes" do
        post :bitbucket, params: {
          repository: {
            name: project.repository_slug
          }
        }.merge(bitbucket_params)
        testrun = TestRun.last
        testrun.tracked_branch_id.must_equal tracked_branch.id
        testrun.commit_sha.must_equal commit_sha
        testrun.status.code.must_equal TestStatus::SETUP
      end

      it "responds with :ok" do
        post :bitbucket, params: {
          repository: {
            name: project.repository_slug
          }
        }.merge(bitbucket_params)
        assert_response :ok
      end
    end
  end
end
