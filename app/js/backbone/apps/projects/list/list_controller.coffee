@App.module "ProjectsApp.List", (List, App, Backbone, Marionette, $, _) ->

  class List.Controller extends App.Controllers.Application

    initialize: ->
      projects = App.request "project:entities"

      user = App.request "current:user"

      projectsView = @getProjectsView(projects, user)

      addProject = =>
        App.ipc("show:directory:dialog")
        .then (dirPath) ->
          ## if the user cancelled the dialog selection
          ## dirPath will be undefined
          return if not dirPath

          ## initially set our project to be loading state
          project = projects.add({path: dirPath, loading: true})

          ## wait at least 750ms even if add:project
          ## resolves faster to prevent the sudden flash
          ## of loading content which is jarring
          Promise.all([
            App.ipc("add:project", dirPath),
            Promise.delay(750)
          ])
          .then ->
            ## our project is now in the loaded state
            ## and can be started
            project.loaded()

        .catch (err) =>
          @displayError(err.message)

      startProject = (project, options = {}) ->
        App.vent.trigger "project:clicked", project, options

      @listenTo projectsView, "add:project:clicked", addProject

      ## listen for the buttons in our empty view too
      @listenTo projectsView, "childview:add:project:clicked", addProject

      @listenTo projectsView, "childview:help:clicked", ->
        App.ipc("external:open", "https://on.cypress.io/guides/installing-and-running/#section-adding-projects")

      @listenTo projectsView, "sign:out:clicked", ->
        App.vent.trigger "log:out", user

      @listenTo projectsView, "childview:project:clicked", (iv, obj) ->
        project = obj.model

        ## bail if our project is loading
        return if project.isLoading()

        startProject(project)

      @listenTo projectsView, "childview:project:remove:clicked", (iv, project) ->
        projects.remove(project)

        App.ipc("remove:project", project.get("path"))

      @listenTo projects, "fetched", ->
        @show projectsView

    displayError: (msg) ->
      errorView = @getErrorView(msg)

      @show errorView

      ## we'll lose all event listeners
      ## if we attach this before show
      ## so we need to wait until after
      @listenTo errorView, "ok:clicked", ->
        @initialize()

    getErrorView: (msg) ->
      new List.Error
        message: msg

    getProjectsView: (projects, user) ->
      new List.Projects
        collection: projects
        model: user