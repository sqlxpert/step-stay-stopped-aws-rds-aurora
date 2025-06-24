# Step-Stay Stopped, RDS and Aurora!

_Keep AWS databases stopped when not needed, with a Step Function_

## Purpose

This is a low-code, AWS Step Function-based alternative to my AWS Lambda-based
tool for stopping RDS and Aurora databases that AWS has automatically started
after the 7-day maximum stop period. Both use the same reliable algorithm.

||Step Function (here)|Lambda|
|---:|:---:|:---:|
|github.com/sqlxpert/|[step-stay-stopped-aws-rds-aurora](https://github.com/sqlxpert/step-stay-stopped-aws-rds-aurora)|[stay-stopped-aws-rds-aurora](https://github.com/sqlxpert/stay-stopped-aws-rds-aurora#stay-stopped-rds-and-aurora)|
|Status|Experimental|Supported|
|Lines of code|&asymp;&nbsp;200|&asymp;&nbsp;333|
|[EventBridge rule](https://docs.aws.amazon.com/eventbridge/latest/userguide/eb-rules.html) target|Step Function|SQS queue, to Lambda function|
|Event and response transformation|[JSONata](https://docs.jsonata.org)|Python|
|API calls|[AWS SDK integration](https://docs.aws.amazon.com/step-functions/latest/dg/supported-services-awssdk.html)|[boto3 RDS client](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/rds.html)|
|Decisions and branching|[Choice states](https://docs.aws.amazon.com/step-functions/latest/dg/state-choice.html)|Python control flow statements|
|Error handling|[Catchers](https://docs.aws.amazon.com/step-functions/latest/dg/concepts-error-handling.html#error-handling-fallback-states) on task states|`try`...`except`|
|Retry mechanism|[Wait state](https://docs.aws.amazon.com/step-functions/latest/dg/state-wait.html)|[Queue message [in]visibility&nbsp;timeout](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-visibility-timeout.html)|
|Timeout mechanism|[State machine TimeoutSeconds](https://docs.aws.amazon.com/step-functions/latest/dg/statemachine-structure.html#statemachinetimeoutseconds)|[maxReceiveCount](https://docs.aws.amazon.com/AWSSimpleQueueService/latest/SQSDeveloperGuide/sqs-dead-letter-queues.html#policies-for-dead-letter-queues)|

### Step Function Advantages

#### 1. Faster development, testing and debugging

Quite frankly, it is a miracle that **200 lines of JSON can replace 333 lines
of executable Python** code. Development is significantly faster, whether you
add states visually or write or edit the JSON manually.

Testing and debugging are moderately faster. Although a correct state machine,
able to handle error conditions, is liable to be more complex than the
initial, normal-case design, even a complex state machine diagram becomes
readable when it's marked up with the traversal from a particular run. The
full log, viewed inside the Step Functions console, shows data at the start
and end of each state traversed, as well as data available for use in between,
such as API responses.

#### 2. Less maintenance

Clearly, Step Functions require less maintenance. Although Step Functions may
call AWS Lambda functions, many problems can be solved without recourse to
Lambda, so that there is no software to patch &mdash; not even a runtime to
update every few months.

#### 3. Low cost

Step Functions are perfect for processes that require lots of wall-clock time
but little actual computing time, such as waiting for a database to start and
then seeing a stop request through until the database is stopped again.
The
[Step Function standard mode price is 25&cent; per 10,000 transitions](https://aws.amazon.com/step-functions/pricing/#AWS_Step_Functions_Standard_Workflow_State_transitions_pricing)
(arrows traversed, on the state machine diagram), regardless of time spent. To
put this in perspective, 10 or fewer state transitions occur every 9 minutes,
from the time AWS starts a database until it is stopped again. Prices vary by
region and may change.

### Step Function Disadvantages

#### 1. Inconsistent error names

These inconsistencies are bugs waiting to happen. For example, the key
StopDBInstance error has 3 different names:

  1. boto3 (AWS Python SDK) exception name:
     [`InvalidDBInstanceStateFault`](https://boto3.amazonaws.com/v1/documentation/api/latest/reference/services/rds/client/stop_db_instance.html)
  2. boto3
     [ClientError](https://boto3.amazonaws.com/v1/documentation/api/latest/guide/error-handling.html#parsing-error-responses-and-catching-exceptions-from-aws-services)
     code: `InvalidDBInstanceState`. This matches the
     [API error](https://docs.aws.amazon.com/AmazonRDS/latest/APIReference/API_StopDBInstance.html#API_StopDBInstance_Errors).
  3. Step Functions error name: `Rds.InvalidDbInstanceStateException`.
     There is even a
     [special note about the Exception suffix](https://docs.aws.amazon.com/step-functions/latest/dg/supported-services-awssdk.html#use-awssdk-integ)!

Another the StopDBInstance error, whose boto3 ClientError code is
`InvalidParameterCombination`, becomes `Rds.RdsException` in Step Functions.

#### 2. Rudimentary retries

[The AWS Python SDK automates retries](https://boto3.amazonaws.com/v1/documentation/api/latest/guide/retries.html#standard-retry-mode)
in response to 18 different exceptions and 4 general HTTP status codes. You
would have to experiment to discover the Step Function service's name for each
of the 26 error conditions (there is no comprehensive document), list all 26
in the `ErrorEquals` field of the
[retrier](https://docs.aws.amazon.com/step-functions/latest/dg/concepts-error-handling.html#error-handling-retrying-after-an-error),
and duplicate the list in every state that makes an AWS API request. That's not
practical.

Thankfully, stopping an RDS or Aurora database is a watch-and-wait operation.
Natural retries with long pauses in between make it unnecessary to match
boto3's diligent retry logic, meant to guard a single, critical AWS API
request.

#### 3. Limited logging control

Logs ought to be very quiet, if the fable
[The Boy Who Cried Wolf](https://en.wikipedia.org/wiki/The_Boy_Who_Cried_Wolf),
the saying "All emphasis is no emphasis",
and the
[Three Mile Island nuclear accident](https://en.wikipedia.org/wiki/Three_Mile_Island_accident)
are any guide.

> The computer printer registering alarms was running more than 2&frac12; hours
behind the events and at one point jammed, thereby losing valuable information.

<details>
  <summary>References...</summary>

- _Report of the President's Commission on the Accident at Three Miles Island_,
  October, 1979, Page 30
- Direct link:
  [archive.org](https://archive.org/details/three-mile-island-report/page/30/mode/1up)
- Backup:
  [US Department of Energy Office of Scientific and Technical Information](https://www.osti.gov/biblio/6986994)
- In the backup source, 2&frac12; hours was mis-scanned as "2-k hours", an
  error that has been repeated as "2000 hours" in at least one book. The
  printer backlog did not reach 83 days; 2&frac12; hours was bad enough!

</details>

[Log levels for Step Function execution events](https://docs.aws.amazon.com/step-functions/latest/dg/cw-logs.html#cloudwatch-log-level)
are limited to `ALL`, `ERROR`, `FATAL`, and `OFF`. Because StopDBCluster and
StopDBInstance are not idempotent, it is normal to call multiple times and
receive InvalidDBCluster and InvalidDBInstanceState errors, both before a
database is `available` and while it is `stopping`. In Python, I can choose to
log these expected exceptions at the `INFO` level rather than the `ERROR`
level, so that you know you can ignore them. Step Functions logs any exception
as an `ERROR`.

#### 4. Cluttered diagrams

Reliably re-stopping an RDS or Aurora database &mdash; that is, avoiding
[race conditions](https://en.wikipedia.org/wiki/Race_condition)
that might leave it running unexpectedly and waste money &mdash; is a complex
process. State machine diagrams generated automatically by the Step Functions
service are hard to read, with excessive cross-overs, tiny print, and
truncated labels. You cannot edit them manually. Their explanatory value falls
off as soon as you add error-handling logic to your state machine. Admittedly,
without Step Functions you have to create your own diagram.

Compare:

[<img src="media/step-stay-stopped-aws-rds-aurora-flow-auto-thumb.png" alt="A 'Choice' state named 'Dispatch' branches out to 'Stop Database Instance' and 'Stop Database Cluster' states. The 'Stop Database Instance' state feeds into a 'Describe Database Instances' state. The 'Describe Database Instances' and 'Stop Database Cluster' states both feed into a 'Choice' state named 'Database Status', which branches out to 'Wait' and 'Success' states. The 'Wait' state feeds back into the 'Dispatch' state. This describes an error-free state machine run, under the default configuration." height="144" />](media/step-stay-stopped-aws-rds-aurora-flow-auto.png?raw=true "Automatically-generated state machine diagram for Step-Stay Stopped, RDS and Aurora!")
[<img src="media/stay-stopped-aws-rds-aurora-architecture-and-flow-thumb.png" alt="Relational Database Service Event Bridge events '0153' and '0154' (database started after exceeding 7-day maximum stop time) go to the main Simple Queue Service queue. The Amazon Web Services Lambda function stops the RDS instance or the Aurora cluster. If the database's status is invalid, the queue message becomes visible again in 9 minutes. A final status of 'stopping', 'deleting' or 'deleted' ends retries, as does an error status. After 160 tries (24 hours), the message goes to the error (dead letter) SQS queue." height="144" />](media/stay-stopped-aws-rds-aurora-architecture-and-flow.png?raw=true "Architecture diagram and flowchart for Stay Stopped, RDS and Aurora!")

### Step Functions Win!

**The advantages of Step Functions far outweigh the disadvantages.** If you
take the time to understand the _semantics_ of AWS APIs and build appropriate
error-handling logic into your state machine &mdash; in other words, if your
solution is _correct_ &mdash; then a compact, predominantly declarative
implementation with a graphical representation cuts development time,
simplifies testing, and reduces maintenance effort.

AWS is actively improving the service. For example, the
[transition from JSONPath to JSONata](https://aws.amazon.com/blogs/compute/simplifying-developer-experience-with-variables-and-jsonata-in-aws-step-functions/),
begun in 2024, has significantly increased the declarative capabilities of Step
Functions. It's possible that some of the disadvantages I noticed will be
addressed in the future.

## Get Started

 1. Log in to the AWS Console as an administrator. Choose an AWS account and a
    region where you have an RDS or Aurora database that is normally stopped,
    or that you can stop now and leave stopped for 8 days.

 2. Create a
    [CloudFormation stack](https://console.aws.amazon.com/cloudformation/home)
    "With new resources (standard)". Select "Upload a template file", then
    select "Choose file" and navigate to a locally-saved copy of
    [step_stay_stopped_aws_rds_aurora.yaml](/step_stay_stopped_aws_rds_aurora.yaml?raw=true)
    [right-click to save as...]. On the next page, set:

    - Stack name: `StepStayStoppedRdsAurora`

 3. Wait 8 days, then check that your
    [RDS or Aurora database](https://console.aws.amazon.com/rds/home#databases:)
    is stopped. After clicking the RDS database instance name or the Aurora
    database cluster name, open the "Logs & events" tab and scroll to "Recent
    events". At the right, click to change "Last 1 day" to "Last 2 weeks". The
    "System notes" column should include the following entries, listed here
    from newest to oldest. There might be other entries in between.

    |RDS|Aurora|
    |:---|:---|
    |DB instance stopped|DB cluster stopped|
    |DB instance started|DB cluster started|
    |DB instance is being started due to it exceeding the maximum allowed time being stopped.|DB cluster is being started due to it exceeding the maximum allowed time being stopped.|

    > If you don't want to wait 8 days, see
    [Testing](#testing),
    below.

## Multi-Account, Multi-Region

For reliability, Step-Stay-Stopped works independently in each region, in each
AWS account. To deploy in multiple regions and/or multiple AWS accounts,

 1. Delete any standalone `StepStayStoppedRdsAurora` CloudFormation _stacks_ in
    your target regions and/or AWS accounts.

 2. Complete the prerequisites for creating a _StackSet_ with
    [service-managed permissions](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/stacksets-orgs-enable-trusted-access.html).

 3. In the management AWS account (or a delegated administrator account),
    create a
    [CloudFormation StackSet](https://console.aws.amazon.com/cloudformation/home#/stacksets).
    Select "Upload a template file", then select "Choose file" and upload a
    locally-saved copy of
    [step_stay_stopped_aws_rds_aurora.yaml](/step_stay_stopped_aws_rds_aurora.yaml?raw=true)
    [right-click to save as...]. On the next page, set:

    - StackSet name: `StepStayStoppedRdsAurora`

 4. Two pages later, under "Deployment targets", select "Deploy to
    Organizational Units". Enter your target `ou-` identifier.
    Step-Stay-Stopped will be deployed in all AWS accounts in your target OU.
    Toward the bottom of the page, specify your target region(s).

## Terraform

Terraform users are often willing to wrap a CloudFormation stack in HashiCorp
Configuration Language, because AWS supplies tools in the form of
CloudFormation templates. See
[aws_cloudformation_stack](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack)
.

Wrapping a CloudFormation StackSet in HCL is much easier than configuring and
using Terraform to deploy and maintain identical resources in multiple regions
and/or AWS accounts. See
[aws_cloudformation_stack_set](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/cloudformation_stack_set)
.

## Security

> In accordance with the software license, nothing in this document establishes
indemnification, a warranty, assumption of liability, etc. Use this software
entirely at your own risk. You are encouraged to review the source code.

<details>
  <summary>Security details...</summary>

### Security Design Goals

- A least-privilege role for the AWS Step Function.

- A least-privilege queue policies. The error (dead letter) queue can only
  consume messages from EventBridge. Encryption in transit is required.

- Optional encryption at rest with the AWS Key Management System, for the
  queue and the log. This can protect EventBridge events containing database
  identifiers and metadata, such as tags. KMS keys housed in a different AWS
  account, and multi-region keys, are supported.

- No data storage other than in the queue and the log, both of which have
  configurable retention periods.

- A per-request timeout, a retry mechanism, and an overall Step Function
  state machine timeout, to increase the likelihood that a database will be
  stopped as intended but prevent endless retries.

- A 24-hour event date/time expiry check, to prevent processing of accumulated
  stale events, if any.

- Readable Identity and Access Management policies, formatted as
  CloudFormation YAML rather than JSON, and broken down into discrete
  statements by service, resource or principal.

### Your Security Steps

- Prevent people from modifying components of this tool, most of which can be
  identified by `StepStayStoppedRdsAurora` in ARNs and in the automatic
  `aws:cloudformation:stack-name` tag.

- Log infrastructure changes using CloudTrail, and set up alerts.

- Prevent people from directly invoking the Step Function and from passing
  the function role to arbitrary functions.

- Separate production workloads. Although this tool only stops databases that
  _AWS_ is starting after they've been stopped for 7 days, the Lambda function
  could stop _any_ database if invoked directly, with a contrived event as
  input. You might choose not to deploy this tool in AWS accounts used for
  production, or you might add a custom IAM policy to the function role,
  denying authority to stop certain production databases (`AttachLocalPolicy`
  in CloudFormation).

- Enable the test mode only in a non-critical AWS account and region, and turn
  the test mode off again as quickly as possible.

- Monitor the error (dead letter) queue, and monitor the log.

- Configure [budget alerts](https://docs.aws.amazon.com/cost-management/latest/userguide/budgets-action-configure.html)
  and use
  [cost anomaly detection](https://docs.aws.amazon.com/cost-management/latest/userguide/manage-ad.html).

- Occasionally start a database before its maintenance window and leave it
  running, to catch up with RDS and Aurora security updates.

</details>

## Troubleshooting

Check the:

 1. [StepStayStoppedRdsAurora-StepFn CloudWatch log group](https://console.aws.amazon.com/cloudwatch/home#logsV2:log-groups$3FlogGroupNameFilter$3DStepStayStoppedRdsAurora-StepFn)
    - Scrutinize log entries at the `ERROR` level:

      `InvalidDBInstanceState` or `InvalidDBClusterStateFault` :

      - One time:
        A database could not be stopped because it was in an unexpected state.
      - Multiple times for the same database:
        The database was in an unexpected but potentially recoverable state.
        Step-Stay-Stopped retries every 9 minutes, until 24 hours have passed.

    - Log entries are JSON objects.
      - Step-Stay-Stopped includes `"level"` , `"type"` and `"value"` keys.
      - Other software components may use different keys.
    - For more data, change the `LogLevel` in CloudFormation.

 2. `StepStayStoppedRdsAurora-ErrorQueue` (dead letter)
    [SQS queue](https://console.aws.amazon.com/sqs/v3/home#/queues)
    - A message in this queue means that Step-Stay-Stopped did not stop a
      database, usually after trying for 24 hours.
    - The message will usually be the original EventBridge event from when AWS
      started the database after it had been stopped for 7 days.
    - Rarely, a message in this queue indicates that the local security
      configuration is denying necessary access to SQS or Lambda.

 3. [CloudTrail Event history](https://console.aws.amazon.com/cloudtrailv2/home?ReadOnly=false/events#/events?ReadOnly=false)
    - CloudTrail events with an "Error code" may indicate permissions
      problems,
      typically due to the local security configuration.
    - To see more events, change "Read-only" from `false` to `true` .

## Testing

<details>
  <summary>Testing details...</summary>

### Recommended Test Database

An RDS database instance ( `db.t4g.micro` , `20` GiB of gp3 storage, `0` days'
worth of automated backups) is cheaper than a typical Aurora cluster, not to
mention faster to create, stop, and start.

### Test Mode

AWS starts RDS and Aurora databases that have been stopped for 7 days, but we
need a faster mechanism for realistic, end-to-end testing. Temporarily change
these parameters in CloudFormation:

**UPDATES PENDING**

|Parameter|Normal|Test|
|:---|:---:|:---:|
|`Test`|`false`|`true`|
|`LogLevel`|`ERROR`|`INFO`|
|`QueueVisibilityTimeoutSecs`|`540`|`60`|
|&rarr; _Equivalent in minutes_|_9 minutes_|_1 minute_|
|`QueueMaxReceiveCount`|`160`|`30`|
|&rarr; _Equivalent time_|_24 hours_|_30 minutes_|

Given the operational and security risks explained below, **&#9888; exit test
mode as quickly as possible**. If your test database is ready, several minutes
should be sufficient.

### Test by Manually Starting a Database

In test mode, Step-Stay-Stopped responds to user-initiated, non-forced database
starts, too:
[RDS-EVENT-0088 (RDS database instance)](https://docs.aws.amazon.com/AmazonRDS/latest/UserGuide/USER_Events.Messages.html#RDS-EVENT-0088)
and
[RDS-EVENT-0151](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/USER_Events.Messages.html#USER_Events.Messages.cluster)
(Aurora database cluster). Although it won't stop databases that are already
running and remain running, **&#9888; while in test mode Step-Stay-Stopped will
stop databases that you start manually**. To test, manually
start a stopped
[RDS or Aurora database](https://console.aws.amazon.com/rds/home#databases:).

> In test mode, Step-Stay-Stopped also receives
[RDS-EVENT-0088 (Aurora database instance)](https://docs.aws.amazon.com/AmazonRDS/latest/AuroraUserGuide/USER_Events.Messages.html#RDS-EVENT-0088).
Internally, the code ignores it in favor of the cluster-level event.

### Test by Invoking the Step Function

Depending on locally-determined permissions, you may also be able to invoke
the
[StepStayStopped Step Function](https://console.aws.amazon.com/lambda/home#/functions?fo=and&o0=%3A&v0=StepStayStoppedRdsAurora-StepFn-)
manually. Edit the database names and date/time strings (must be within the past
`QueueMaxReceiveCount` &times; `QueueVisibilityTimeoutSecs` and end in `Z` for
[UTC](https://www.timeanddate.com/worldclock/timezone/utc))
in these test messages:

```json
{
  "detail": {
    "SourceIdentifier": "Name-Of-Your-RDS-Database-Instance",
    "Date": "2025-06-06T04:30Z",
    "SourceType": "DB_INSTANCE",
    "EventID": "RDS-EVENT-0154"
  },
  "detail-type": "RDS DB Instance Event",
  "source": "aws.rds",
  "version": "0"
}
```

```json
{
  "detail": {
    "SourceIdentifier": "Name-Of-Your-Aurora-Database-Cluster",
    "Date": "2025-06-06T04:30Z",
    "SourceType": "CLUSTER",
    "EventID": "RDS-EVENT-0153"
  },
  "detail-type": "RDS DB Cluster Event",
  "source": "aws.rds",
  "version": "0"
}
```

### Report Bugs

After following the
[troubleshooting](#troubleshooting)
steps and ruling out local issues such as permissions &mdash; especially
hidden controls such as Service and Resource control policies (SCPs and RCPs)
&mdash; please
[report bugs](/../../issues). Thank you!

</details>

## Licenses

|Scope|Link|Included Copy|
|:---|:---|:---|
|Source code, and source code in documentation|[GNU General Public License (GPL) 3.0](http://www.gnu.org/licenses/gpl-3.0.html)|[LICENSE-CODE.md](/LICENSE-CODE.md)|
|Documentation, including this ReadMe file|[GNU Free Documentation License (FDL) 1.3](http://www.gnu.org/licenses/fdl-1.3.html)|[LICENSE-DOC.md](/LICENSE-DOC.md)|

Copyright Paul Marcelin

Contact: `marcelin` at `cmu.edu` (replace "at" with `@`)
