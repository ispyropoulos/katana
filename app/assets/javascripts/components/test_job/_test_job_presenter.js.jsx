var ReactCSSTransitionGroup = React.addons.CSSTransitionGroup;
var TestJobPresenter = React.createClass({
  getInitialState: function () {
    return ({ testJobs: this.props.test_jobs,
              testRun: this.props.test_run,
              projectId: this.props.project_id,
              user_can_manage_run: this.props.user_can_manage_run,
              admin_user: this.props.admin_user,
              test_runs_link: this.props.test_runs_link
            })
  },

  handleUpdate: function (msg) {
    var testJobs = this.state.testJobs;

    var updateTestJobs = function(testJobs, msg) {
      if (msg.event == 'TestRunRetry') {
        this.setState({ testJobs: [] })
      } else if (msg.event == 'TestRunUpdate' && msg.test_run) {
        this.setState({ testRun: msg.test_run })
      } else if (msg.event == 'TestJobUpdate' && msg.test_job) {
        existedJob =  _.find(this.state.testJobs, function(testJob) {
          return testJob.id == msg.test_job.id;
        })
        if (existedJob) {
          testJobs.splice(testJobs.indexOf(existedJob), 1, msg.test_job)
          this.setState({ testJobs: testJobs })
        } else {
          if (msg.test_job.id) {
            testJobs.push(msg.test_job)
            this.setState({ testJobs: testJobs})
          } else {
            null
          };
        }
      }
    }.bind(this)

    updateTestJobs(testJobs, msg)
  },

  subscribe: function (testJobIds) {
    var _this = this;
    var subscriptions = {
      "TestRun": {
        'ids': [this.props.test_run.id]
      }
    }

    window.liveUpdates.initConnection()
    window.liveUpdates.subscribe(subscriptions, _this.handleUpdate)
  },

  componentDidMount: function() {
    var testJobIds = this.props.test_jobs.map(function(testJob, index){
      return testJob.id;
    });
    this.subscribe(testJobIds)
  },

  render: function () {
    return (
      <div className='panelized'>
        <div className='row m-t-10'>
          <ReactCSSTransitionGroup
            transitionName="build-react-style"
            transitionAppear={true}
            transitionAppearTimeout={50}
            transitionEnterTimeout={50}
            transitionLeaveTimeout={50}>
            <TestRunShowHeader
              test_run={ this.state.testRun }
              user_can_manage_run={ this.props.user_can_manage_run }
              test_runs_link={ this.props.test_runs_link}
              key={1} />
          </ReactCSSTransitionGroup>
          <div className='col-xs-12'>
            <ProgressBars statuses={ this.state.testRun.statuses }
                             total={ this.state.testRun.statuses.total }
                     display_stats={ true }
                               key={2} />
          </div>
        </div>
        <div className='row'>
          <div className='col-xs-12'>
             <TestJobList
              test_jobs={this.state.testJobs}
              user_can_manage_run={ this.props.user_can_manage_run }
              admin_user={ this.props.admin_user}
              key={3} />
          </div>
        </div>
      </div>
    );
  }
})
