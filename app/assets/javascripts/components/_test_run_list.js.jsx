var TestRunList = React.createClass({
  render: function () {
    var maxIndexRun = _.max(this.props.testRuns, function(testRun){ return testRun.run_index; });
    var testRunNodes = this.props.testRuns.map(function ( testRun ) {
      return <TestRun testRun={ testRun } key={ testRun.id } maxIndexRunId={ maxIndexRun.id } userCanManageRun={ this.props.userCanManageRun} />
  }.bind(this));

    return (
      <table className='table'>
        <thead>
          <tr>
            <th>Build</th>
            <th>Commit message (SHA)</th>
            <th>Status</th>
            <th>Results</th>
            <th>Duration</th>
            <th>Actions</th>
          </tr>
        </thead>
        <tbody>
          { testRunNodes }
        </tbody>
      </table>
    )
  }
});
