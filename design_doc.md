# Open source projects

This is a temporary document for the lifespan of the working branch. It describes
the feature to be implemented.

## Why

In order to create traction and make Testributor known to the world of programmers,
we will add support for open source projects. Altough Testributor is designed to
be able to run any project, in practice open source projects have some unique
characteristics and demands. E.g.

- Build results should be public. Everyone should be able to visit the
  result pages. Settings and the rest should only be accessible by the project
  owner and maybe the invited users.

- Most open sources projects are components rather than complete applications
  (e.g. gems, libraries). Components are usually tested in a variety of environments,
  different versions of libraries and languages. For example, most gems are
  tested against multiple versions of Ruby.

- The maintainer should be able to manage, monitorm, block and maybe restart
  workers at will. For example, many "contributors" might spawn workers. If
  one is missbehaving, the maintainer should be able to tell which user's
  worker (on testributor) this is and remove it if needed.

- Many open source projects already have Travis or CircleCI configuration files
  in place. We could use them to automatically generate our testributor.yml
  file.
