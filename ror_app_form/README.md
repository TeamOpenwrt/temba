# README

This is a rails application that allows user to download a firmware based on some parameters in a form. At some point is probably going to do more things: more forms or even an app

This application at the moment does not use a database, but there is a model `@node` to perform validations in the form

## Run server

    rails s

## Javascript

At the moment no third party stuff is used (that means no jquery)

Javascript is used for two things

### Online users

When you enter the form you got subscribed to a channel of ActiveCable that says how many users are there.

### Download file

As can be concurrently users requesting a firmware build, an ActiveJob is required to handle a queue for all the request. The build process is not concurrent (that means only 1 worker).

The way the form has to know that the file is ready we use javascript. When the form (HTTP POST) is accepted the server returns the identifier of the file. In that moment, with a `XMLHttpRequest`, it asks to an API entrypoint with polling technique (each 4 seconds) if the file is ready. When the file is ready, the API returns the parameters to download the file, this is done again with a javascript redirection.

