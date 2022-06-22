# helm-random-testing

This simple chart is for demonstrating a technique for allowing a random password to be created at install time, but to then never update that password unless provided in as a concrete value. This may be useful if you want to either allow a hard coded password to be used, or to let a random value be generated if none was provided. The specifics I ran into was in a chart that would create in in-cluster PostgreSQL database instance with a random password by default, but on a later upgrade you could change the source to be an external database, which would require changing the password to match the target.

The two methods here differ in that the one in [secret.yaml](templates/secret.yaml) uses Helm hooks, has the side-effect of the resource not being managed by Helm, which causes it to be replaced every time a hook is triggered. The method used for [other-secret.yaml](templates/other-secret.yaml) uses Helm lookup instead, which creates a normally managed Helm resource.

To see how the chart works you can run `test.sh` to install and upgrade the chart through a few scenarios.
