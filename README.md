[![Build Status](http://www.testributor.com/projects/34-testributor/status?branch=master)][testributor] [![Gitter](https://img.shields.io/gitter/room/gitterHQ/gitter.svg)][gitter-chat]

[testributor]: http://www.testributor.com/projects/34-testributor
[gitter-chat]: https://gitter.im/testributor/testributor

# Testributor - Katana

Katana is part of the [Testributor](http://about.testributor.com) open source
Continuous Integration platform. It is the main server application providing
the API for the agents, the User Interface and all the logic for
Authorization/Authentication.

## Dependencies

Katana is a Ruby on Rails application and it needs:
  - PostgreSQL for storage
  - Redis as a PUB/SUB system
  - [Socketidio](https://github.com/testributor/socketidio)
  - At least one running [Sidekiq](https://github.com/mperham/sidekiq) worker

## Running the application

In the future we might provide some easy ways to run Testributor (Docker image,
AMI etc) but for now you will have to create and run all components on your own.
Here is the walkthrough:

- Clone this project to a directory on your system. E.g.

```
git clone git@github.com:testributor/katana.git
```

### Database preparation

- Move to the cloned project's directory: `cd katana`
- Copy `config/database.local.sample.yml` file to `config/database.local.yml`:

```
cp config/database.local.sample.yml config/database.local.yml
```

- Edit the file and change the database details to match a PostgreSQL database
  which you want to use.
- Unless the database is already created, run `rake db:create` to create it now.
- Run `rake db:setup` to load the schema and prepare the database.

### Run Socketidio

Follow the instructions on [Socketidio README](https://github.com/testributor/socketidio)
in order to run socketidio (by default on port 9000).

### Start a background Sidekiq worker

For the application to work you need to have at least one running Sidekiq worker.
From withing the katana project directory run the following command to start one:

```
bundle exec sidekiq -c 3 -q mailers -q default -q low

```

### Environment variables

Testributor uses some environment variables for configuration and you will not
be able to start the application unless they are defined. These are:

- `GITHUB_CLIENT_ID` and `GITHUB_CLIENT_SECRET`
  You will need to create an application on GitHub as described [here](https://developer.github.com/guides/basics-of-authentication/#registering-your-app) to obtain these values.

- `BITBUCKET_CLIENT_ID` and `BITBUCKET_CLIENT_SECRET`
  These are the same values for Bitbucket. Read how to create an application on
  Bitbucket [here](https://confluence.atlassian.com/display/bitbucket/oauth+on+bitbucket+cloud#OAuthonBitbucketCloud-Createaconsumer).

- `ENCRYPTED_TOKEN_SECRET`
  Keys and API tokens are stored encrypted in the database. This value is the
  key used for encryption. Use a big random string value for this variable.

- `SOCKETIO_URL`
  This is the url of the socketidio which you started on a previous step. The
  default value is "http://localhost:9000" and you don't need to define this
  variable if this is correct for your system.

### Start the application

While in the katana project directory start the Rails server:

```
bin/rails s
```

## Contributing

You are more than welcome to contribute to the development of Testributor CI with
bug fixes or new features. We suggest that you first open an
[Issue](https://github.com/testributor/katana/issues) in order to discuss the
bug/feature before jumping to implementation. This will make planning of features
more efficient and will save us from duplicate efforts in case someone has already
started working on something.

In any case, if you decide to work on something:
  - Fork the project
  - Do your magic
  - Open a Pull Request
  - Wait patiently for someone to review your code

Make sure you test your code. Ask for help if you need it. Here some general
[guidelines](https://guides.github.com/activities/contributing-to-open-source/)
on the subject of contributing.

## License

Katana is released under the [MIT License](https://github.com/testributor/katana/blob/master/LICENSE).
