var TestRun = React.createClass({
  render: function () {
    var testRunCtas = [];

    if (this.props.testRun.id == this.props.maxIndexRunId || this.props.testRun.is_running) {
      if (this.props.testRun.can_be_cancelled && this.props.userCanManageRun) {
        testRunCtas.push(<TestRunCancelButton cancelUrl={ this.props.testRun.cancel_url } key={1}/>)
      }
      if (this.props.testRun.can_be_retried && this.props.userCanManageRun) {
        testRunCtas.push(<TestRunRetryButton retryUrl={ this.props.testRun.retry_url } key={2}/>)
      }
    }

    return (
      <tr id={ 'test-run-' + this.props.testRun.id } className='test-run-tr'>
        <td className="col-md-1">
          <a href={ this.props.testRun.test_run_link }>#{ this.props.testRun.run_index }</a>
        </td>
        <td className="col-md-4">
          { this.props.testRun.commit_message }
          <br></br>
          <i> { this.props.testRun.commit_author } committed <span title={ this.props.testRun.commit_timestamp }> { this.props.testRun.commit_time_ago } ago</span></i>
        </td>
        <td className="col-md-1 status">
          <div className='status-label'>
            <span className={ this.props.testRun.status_css_class }>{ this.props.testRun.status_text }</span>
          </div>
        </td>
        <td className="col-md-3">
          <a href={ this.props.testRun.test_run_link }>
            <ProgressBars statuses={ this.props.testRun.statuses } total={ this.props.testRun.statuses.total } key={3} />
          </a>
        </td>
        <td className="col-md-1 running_time">
          { this.props.testRun.total_running_time }
        </td>
        <td className="col-md-2" >
          <div className="m-t-5">
            { testRunCtas }
          </div>
        </td>
      </tr>
    )
  }
});
