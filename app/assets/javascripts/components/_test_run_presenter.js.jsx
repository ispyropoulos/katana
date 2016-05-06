var TestRunPresenter = React.createClass({
  getInitialState: function () {
    return { testRuns: this.props.testRuns }
  },

  handleUpdate: function (msg) {
    var testRuns = this.state.testRuns;
    if (msg.test_run) {
      existedRun =  _.find(this.state.testRuns, function(testRun) {
        return testRun.id == msg.test_run.id;
      })

      if (existedRun) {
        testRuns.splice(testRuns.indexOf(existedRun),1, msg.test_run)
        this.setState({ testRuns: testRuns })
      } else {
        testRuns.unshift(msg.test_run)
        this.setState({ testRuns: testRuns })
      }
    }
  },

  subscribe: function (branchId) {
    var subscriptions = {
      "TrackedBranch":  [branchId]
    }
    var _this = this;

    Testributor.Widgets.LiveUpdates(subscriptions, _this.handleUpdate)
  },

  componentDidMount: function() {
    var _this = this;
    _this.subscribe(this.props.branchId)
  },

  render: function () {
     return (
       <TestRunList testRuns={ this.state.testRuns } userCanManageRun={ this.props.userCanManageRun } />
     )
  }
})
