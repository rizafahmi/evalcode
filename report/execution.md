# Getting Started

```
g worktree add ~/code/worktrees/evalcode_agentname
cp -R ~/code/evalcode ~/code/worktrees/evalcode_agentname_runner
cd ~/code/worktrees/evalcode_runner
rm .git
rm docs/run-autonomous.md
g init
g aa
g ci -m "init"
mix deps.get
mix ecto.reset
mix setup
mix test
mix phx.server
```

Check http://localhost:4000

Run coding agent with full access for example: `agy --dangerously-accept-all`

# DeepSeek Harness - Deepseek v4 Flash High

## M1

total time: 24m20s

### Token and cost

#### Turn usage
26,504,777 tok
Provider / model
deepseek-official/deepseek-v4-flash
Cache hit
99.5%
Uncached input
129,768 tok
Cached input
26,259,712 tok
Output
115,297 tok (78,683 tok reasoning)

#### Context
23%
of context used
~235K / 1M
System prompt
~1.7K
Tools
~6.6K
Messages
~204K

#### Cost
$0.29

More info: ./1-session.v2.jsonl

### Test Coverage

Fixing flake.nix problem: Usage 11.2M tok Ran for 18m51s

Result: 27 passed

Generating cover results ...

| Percentage | Module                                |
|------------|---------------------------------------|
|      0.00% | AlurWeb.AccountRegistrationHTML       |
|      0.00% | AlurWeb.AccountSessionHTML            |
|      0.00% | Inspect.Alur.Accounts.Account         |
|     30.00% | AlurWeb                               |
|     39.37% | AlurWeb.CoreComponents                |
|     50.00% | Alur.Repo                             |
|     50.00% | AlurWeb.ErrorHTML                     |
|     71.43% | Alur.Application                      |
|     76.47% | AlurWeb.AccountAuth                   |
|     80.00% | AlurWeb.Telemetry                     |
|     85.71% | AlurWeb.AccountRegistrationController |
|     90.91% | AlurWeb.Router                        |
|     93.33% | Alur.Accounts                         |
|    100.00% | Alur                                  |
|    100.00% | Alur.Accounts.Account                 |
|    100.00% | Alur.Accounts.AccountToken            |
|    100.00% | Alur.DataCase                         |
|    100.00% | Alur.Mailer                           |
|    100.00% | AlurWeb.AccountSessionController      |
|    100.00% | AlurWeb.ConnCase                      |
|    100.00% | AlurWeb.ContactsLive                  |
|    100.00% | AlurWeb.Endpoint                      |
|    100.00% | AlurWeb.ErrorJSON                     |
|    100.00% | AlurWeb.Layouts                       |
|    100.00% | AlurWeb.PipelineLive                  |
|    100.00% | AlurWeb.TodosLive                     |
|------------|---------------------------------------|
|     66.23% | Total                                 |

Coverage test failed, threshold not met:

    Coverage:   66.23%
    Threshold:  90.00%

## M2
total time: 14m0s

### Token and cost
#### Turn usage
7,860,560 tok
Provider / model
deepseek-official/deepseek-v4-flash
Cache hit
99%
Uncached input
78,898 tok
Cached input
7,709,824 tok
Output
71,838 tok (49,903 tok reasoning)

#### Context Used
15%
of context used
~148K / 1M
System prompt
~1.7K
Tools
~6.6K
Messages
~127K

#### Cost
$0.22

### Test Coverage

Result: 40 passed

Generating cover results ...

| Percentage | Module                                |
|------------|---------------------------------------|
|      0.00% | AlurWeb.AccountRegistrationHTML       |
|      0.00% | AlurWeb.AccountSessionHTML            |
|      0.00% | Inspect.Alur.Accounts.Account         |
|     30.00% | AlurWeb                               |
|     50.00% | Alur.Repo                             |
|     50.00% | AlurWeb.ErrorHTML                     |
|     55.12% | AlurWeb.CoreComponents                |
|     71.43% | Alur.Application                      |
|     76.47% | AlurWeb.AccountAuth                   |
|     80.00% | AlurWeb.Telemetry                     |
|     85.71% | AlurWeb.AccountRegistrationController |
|     92.31% | Alur.Contacts                         |
|     92.86% | AlurWeb.Router                        |
|     93.33% | Alur.Accounts                         |
|     99.06% | AlurWeb.ContactsLive                  |
|    100.00% | Alur                                  |
|    100.00% | Alur.Accounts.Account                 |
|    100.00% | Alur.Accounts.AccountToken            |
|    100.00% | Alur.Contacts.Contact                 |
|    100.00% | Alur.DataCase                         |
|    100.00% | Alur.Mailer                           |
|    100.00% | AlurWeb.AccountSessionController      |
|    100.00% | AlurWeb.ConnCase                      |
|    100.00% | AlurWeb.Endpoint                      |
|    100.00% | AlurWeb.ErrorJSON                     |
|    100.00% | AlurWeb.Layouts                       |
|    100.00% | AlurWeb.PipelineLive                  |
|    100.00% | AlurWeb.TodosLive                     |
|------------|---------------------------------------|
|     80.09% | Total                                 |

Coverage test failed, threshold not met:

    Coverage:   80.09%
    Threshold:  90.00%

Generated HTML coverage results in "cover" directory

## M3
Total time: 16m41s

### Token and cost

#### Turn usage
13,356,335 tok
Provider / model
deepseek-official/deepseek-v4-flash
Cache hit
99.3%
Uncached input
95,335 tok
Cached input
13,182,720 tok
Output
78,280 tok (45,913 tok reasoning)

#### Context
17%
of context used
~172K / 1M
System prompt
~1.7K
Tools
~6.6K
Messages
~147

Cost: $0.13
More info: ./3-session.v2.jsonl


### Test Coverage

Result: 58 passed

Generating cover results ...

| Percentage | Module                                |
|------------|---------------------------------------|
|      0.00% | AlurWeb.AccountRegistrationHTML       |
|      0.00% | AlurWeb.AccountSessionHTML            |
|      0.00% | Inspect.Alur.Accounts.Account         |
|     30.00% | AlurWeb                               |
|     50.00% | Alur.Repo                             |
|     50.00% | AlurWeb.ErrorHTML                     |
|     64.57% | AlurWeb.CoreComponents                |
|     71.43% | Alur.Application                      |
|     76.47% | AlurWeb.AccountAuth                   |
|     80.00% | AlurWeb.Telemetry                     |
|     85.71% | AlurWeb.AccountRegistrationController |
|     92.31% | Alur.Contacts                         |
|     92.31% | Alur.Deals                            |
|     93.33% | Alur.Accounts                         |
|     94.12% | AlurWeb.Router                        |
|     98.73% | AlurWeb.DealsLive                     |
|     99.21% | AlurWeb.ContactsLive                  |
|    100.00% | Alur                                  |
|    100.00% | Alur.Accounts.Account                 |
|    100.00% | Alur.Accounts.AccountToken            |
|    100.00% | Alur.Contacts.Contact                 |
|    100.00% | Alur.DataCase                         |
|    100.00% | Alur.Deals.Deal                       |
|    100.00% | Alur.Deals.PipelineColumn             |
|    100.00% | Alur.Mailer                           |
|    100.00% | AlurWeb.AccountSessionController      |
|    100.00% | AlurWeb.ConnCase                      |
|    100.00% | AlurWeb.Endpoint                      |
|    100.00% | AlurWeb.ErrorJSON                     |
|    100.00% | AlurWeb.Layouts                       |
|    100.00% | AlurWeb.PipelineLive                  |
|    100.00% | AlurWeb.TodosLive                     |
|------------|---------------------------------------|
|     86.24% | Total                                 |

Coverage test failed, threshold not met:

    Coverage:   86.24%
    Threshold:  90.00%

## M4
Total time: 14m04s

### Token and cost

#### Turn usage
11,243,151 tok
Provider / model
deepseek-official/deepseek-v4-flash
Cache hit
99%
Uncached input
112,136 tok
Cached input
11,060,864 tok
Output
70,151 tok (47,102 tok reasoning)

#### Context
18% of context used
~184K / 1M
System prompt
~1.7K
Tools
~6.6K
Messages
~154K

Cost: $0.15

More info: ./4-session.v2.jsonl


### Test Coverage

Result: 67 passed

Generating cover results ...

| Percentage | Module                                |
|------------|---------------------------------------|
|      0.00% | AlurWeb.AccountRegistrationHTML       |
|      0.00% | AlurWeb.AccountSessionHTML            |
|      0.00% | Inspect.Alur.Accounts.Account         |
|     30.00% | AlurWeb                               |
|     50.00% | Alur.Repo                             |
|     50.00% | AlurWeb.ErrorHTML                     |
|     64.57% | AlurWeb.CoreComponents                |
|     71.43% | Alur.Application                      |
|     76.47% | AlurWeb.AccountAuth                   |
|     80.00% | AlurWeb.Telemetry                     |
|     85.71% | AlurWeb.AccountRegistrationController |
|     90.00% | Alur.Deals                            |
|     92.31% | Alur.Contacts                         |
|     93.33% | Alur.Accounts                         |
|     94.12% | AlurWeb.Router                        |
|     98.73% | AlurWeb.DealsLive                     |
|     99.21% | AlurWeb.ContactsLive                  |
|    100.00% | Alur                                  |
|    100.00% | Alur.Accounts.Account                 |
|    100.00% | Alur.Accounts.AccountToken            |
|    100.00% | Alur.Contacts.Contact                 |
|    100.00% | Alur.DataCase                         |
|    100.00% | Alur.Deals.Deal                       |
|    100.00% | Alur.Deals.PipelineColumn             |
|    100.00% | Alur.Mailer                           |
|    100.00% | AlurWeb.AccountSessionController      |
|    100.00% | AlurWeb.ConnCase                      |
|    100.00% | AlurWeb.Endpoint                      |
|    100.00% | AlurWeb.ErrorJSON                     |
|    100.00% | AlurWeb.Layouts                       |
|    100.00% | AlurWeb.PipelineLive                  |
|    100.00% | AlurWeb.TodosLive                     |
|------------|---------------------------------------|
|     87.03% | Total                                 |

Coverage test failed, threshold not met:

    Coverage:   87.03%
    Threshold:  90.00%

## M5

Total time: 14m0s

### Token and cost

#### Turn usage
8,943,037 tok
Provider / model
deepseek-official/deepseek-v4-flash
Cache hit
99.1%
Uncached input
76,913 tok
Cached input
8,799,488 tok
Output
66,636 tok (42,055 tok reasoning)

#### Cotext Used

15% of context used
~146K / 1M
System prompt
~1.7K
Tools
~6.6K
Messages
~124K

Cost: $0.13

More info: ./5-session.v2.jsonl

### Test Coverage

Result: 86 passed

Generating cover results ...

| Percentage | Module                                |
|------------|---------------------------------------|
|      0.00% | AlurWeb.AccountRegistrationHTML       |
|      0.00% | AlurWeb.AccountSessionHTML            |
|      0.00% | Inspect.Alur.Accounts.Account         |
|     30.00% | AlurWeb                               |
|     50.00% | Alur.Repo                             |
|     50.00% | AlurWeb.ErrorHTML                     |
|     60.00% | Alur.Activities                       |
|     64.57% | AlurWeb.CoreComponents                |
|     71.43% | Alur.Application                      |
|     76.47% | AlurWeb.AccountAuth                   |
|     80.00% | AlurWeb.Telemetry                     |
|     85.71% | AlurWeb.AccountRegistrationController |
|     88.57% | Alur.Deals                            |
|     92.31% | Alur.Contacts                         |
|     93.33% | Alur.Accounts                         |
|     94.12% | AlurWeb.Router                        |
|     97.00% | AlurWeb.DealsLive                     |
|     99.21% | AlurWeb.ContactsLive                  |
|    100.00% | Alur                                  |
|    100.00% | Alur.Accounts.Account                 |
|    100.00% | Alur.Accounts.AccountToken            |
|    100.00% | Alur.Activities.Activity              |
|    100.00% | Alur.Contacts.Contact                 |
|    100.00% | Alur.DataCase                         |
|    100.00% | Alur.Deals.Deal                       |
|    100.00% | Alur.Deals.PipelineColumn             |
|    100.00% | Alur.Mailer                           |
|    100.00% | AlurWeb.AccountSessionController      |
|    100.00% | AlurWeb.ConnCase                      |
|    100.00% | AlurWeb.Endpoint                      |
|    100.00% | AlurWeb.ErrorJSON                     |
|    100.00% | AlurWeb.Layouts                       |
|    100.00% | AlurWeb.PipelineLive                  |
|    100.00% | AlurWeb.TodosLive                     |
|------------|---------------------------------------|
|     86.98% | Total                                 |

Coverage test failed, threshold not met:

    Coverage:   86.98%
    Threshold:  90.00%

## M6

Total time: 14m32s

### Token and cost

#### Turn usage
7,904,491 tok
Provider / model
deepseek-official/deepseek-v4-flash
Cache hit
99%
Uncached input
81,328 tok
Cached input
7,748,480 tok
Output
74,683 tok (48,530 tok reasoning)

#### Context Used

16% of context used
~159K / 1M
System prompt
~1.7K
Tools
~6.6K
Messages
~136K

Cost: $0.24
More info: ./6-session.v2.jsonl

### Test Coverage

Result: 106 passed

Generating cover results ...

| Percentage | Module                                |
|------------|---------------------------------------|
|      0.00% | AlurWeb.AccountRegistrationHTML       |
|      0.00% | AlurWeb.AccountSessionHTML            |
|      0.00% | Inspect.Alur.Accounts.Account         |
|     30.00% | AlurWeb                               |
|     50.00% | Alur.Repo                             |
|     50.00% | AlurWeb.ErrorHTML                     |
|     60.00% | Alur.Activities                       |
|     64.57% | AlurWeb.CoreComponents                |
|     71.43% | Alur.Application                      |
|     76.47% | AlurWeb.AccountAuth                   |
|     80.00% | AlurWeb.Telemetry                     |
|     85.71% | AlurWeb.AccountRegistrationController |
|     86.67% | AlurWeb.TodosLive                     |
|     88.57% | Alur.Deals                            |
|     91.67% | Alur.NextActions                      |
|     92.31% | Alur.Contacts                         |
|     93.33% | Alur.Accounts                         |
|     94.03% | AlurWeb.DealsLive                     |
|     94.12% | AlurWeb.Router                        |
|     99.21% | AlurWeb.ContactsLive                  |
|    100.00% | Alur                                  |
|    100.00% | Alur.Accounts.Account                 |
|    100.00% | Alur.Accounts.AccountToken            |
|    100.00% | Alur.Activities.Activity              |
|    100.00% | Alur.Contacts.Contact                 |
|    100.00% | Alur.DataCase                         |
|    100.00% | Alur.Deals.Deal                       |
|    100.00% | Alur.Deals.PipelineColumn             |
|    100.00% | Alur.Mailer                           |
|    100.00% | Alur.NextActions.NextAction           |
|    100.00% | AlurWeb.AccountSessionController      |
|    100.00% | AlurWeb.ConnCase                      |
|    100.00% | AlurWeb.Endpoint                      |
|    100.00% | AlurWeb.ErrorJSON                     |
|    100.00% | AlurWeb.Layouts                       |
|    100.00% | AlurWeb.NextActionComponents          |
|    100.00% | AlurWeb.PipelineLive                  |
|------------|---------------------------------------|
|     87.41% | Total                                 |

Coverage test failed, threshold not met:

    Coverage:   87.41%
    Threshold:  90.00%

## M7

Total time: 18m01s

### Token and cost

#### Context window
14% of context used
~137K / 1M
System prompt
~1.7K
Tools
~6.6K
Messages
~116K

Cost: $0.07
More info: ./7-session.v2.jsonl

### Test Coverage

Result: 109 passed

Generating cover results ...

| Percentage | Module                                |
|------------|---------------------------------------|
|      0.00% | AlurWeb.AccountRegistrationHTML       |
|      0.00% | AlurWeb.AccountSessionHTML            |
|      0.00% | AlurWeb.AppHTML                       |
|      0.00% | Inspect.Alur.Accounts.Account         |
|     30.00% | AlurWeb                               |
|     50.00% | Alur.Repo                             |
|     50.00% | AlurWeb.ErrorHTML                     |
|     60.00% | Alur.Activities                       |
|     64.57% | AlurWeb.CoreComponents                |
|     71.43% | Alur.Application                      |
|     80.00% | AlurWeb.Telemetry                     |
|     85.71% | AlurWeb.AccountRegistrationController |
|     86.67% | AlurWeb.TodosLive                     |
|     88.24% | AlurWeb.AccountAuth                   |
|     88.57% | Alur.Deals                            |
|     91.67% | Alur.NextActions                      |
|     92.31% | Alur.Contacts                         |
|     93.33% | Alur.Accounts                         |
|     94.03% | AlurWeb.DealsLive                     |
|     99.21% | AlurWeb.ContactsLive                  |
|    100.00% | Alur                                  |
|    100.00% | Alur.Accounts.Account                 |
|    100.00% | Alur.Accounts.AccountToken            |
|    100.00% | Alur.Activities.Activity              |
|    100.00% | Alur.Contacts.Contact                 |
|    100.00% | Alur.DataCase                         |
|    100.00% | Alur.Deals.Deal                       |
|    100.00% | Alur.Deals.PipelineColumn             |
|    100.00% | Alur.Mailer                           |
|    100.00% | Alur.NextActions.NextAction           |
|    100.00% | AlurWeb.AccountSessionController      |
|    100.00% | AlurWeb.AppController                 |
|    100.00% | AlurWeb.ConnCase                      |
|    100.00% | AlurWeb.Endpoint                      |
|    100.00% | AlurWeb.ErrorJSON                     |
|    100.00% | AlurWeb.HealthController              |
|    100.00% | AlurWeb.Layouts                       |
|    100.00% | AlurWeb.NextActionComponents          |
|    100.00% | AlurWeb.PipelineLive                  |
|    100.00% | AlurWeb.Router                        |
|------------|---------------------------------------|
|     88.11% | Total                                 |

Coverage test failed, threshold not met:

    Coverage:   88.11%
    Threshold:  90.00%
    

## M8


### Tokens and Cost

### Turn usage
10,893,051 tok
Provider / model
deepseek-official/deepseek-v4-flash
Cache hit
99.3%
Uncached input
76,924 tok
Cached input
10,735,616 tok
Output
80,511 tok (46,087 tok reasoning)

### Context used
16% of context used
~159K / 1M
System prompt
~1.7K
Tools
~6.6K
Messages
~136K

Cost: $0.14

More info: ./8-session.v2.jsonl

### Test Coverage

Result: 122 passed

Generating cover results ...

| Percentage | Module                                |
|------------|---------------------------------------|
|      0.00% | AlurWeb.AccountRegistrationHTML       |
|      0.00% | AlurWeb.AccountSessionHTML            |
|      0.00% | AlurWeb.AppHTML                       |
|      0.00% | Inspect.Alur.Accounts.Account         |
|     30.00% | AlurWeb                               |
|     50.00% | Alur.Repo                             |
|     50.00% | AlurWeb.ErrorHTML                     |
|     60.00% | Alur.Activities                       |
|     64.57% | AlurWeb.CoreComponents                |
|     71.43% | Alur.Application                      |
|     80.00% | AlurWeb.Telemetry                     |
|     85.71% | AlurWeb.AccountRegistrationController |
|     86.67% | AlurWeb.TodosLive                     |
|     88.57% | Alur.Deals                            |
|     88.89% | AlurWeb.AccountAuth                   |
|     91.67% | Alur.NextActions                      |
|     92.31% | Alur.Contacts                         |
|     93.33% | Alur.Accounts                         |
|     94.03% | AlurWeb.DealsLive                     |
|     96.15% | AlurWeb.Api.DealsController           |
|     99.21% | AlurWeb.ContactsLive                  |
|    100.00% | Alur                                  |
|    100.00% | Alur.Accounts.Account                 |
|    100.00% | Alur.Accounts.AccountToken            |
|    100.00% | Alur.Activities.Activity              |
|    100.00% | Alur.Contacts.Contact                 |
|    100.00% | Alur.DataCase                         |
|    100.00% | Alur.Deals.Deal                       |
|    100.00% | Alur.Deals.PipelineColumn             |
|    100.00% | Alur.Mailer                           |
|    100.00% | Alur.NextActions.NextAction           |
|    100.00% | AlurWeb.AccountSessionController      |
|    100.00% | AlurWeb.AppController                 |
|    100.00% | AlurWeb.ConnCase                      |
|    100.00% | AlurWeb.Endpoint                      |
|    100.00% | AlurWeb.ErrorJSON                     |
|    100.00% | AlurWeb.HealthController              |
|    100.00% | AlurWeb.Layouts                       |
|    100.00% | AlurWeb.NextActionComponents          |
|    100.00% | AlurWeb.PipelineLive                  |
|    100.00% | AlurWeb.Router                        |
|------------|---------------------------------------|
|     88.49% | Total                                 |

Coverage test failed, threshold not met:

    Coverage:   88.49%
    Threshold:  90.00%


## Notes

the auth using `/accounts/**`, the name conventions in Phoenix 1.7
