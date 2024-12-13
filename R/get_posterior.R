#' Get posterior values
#'
#' @param fit Fitted model (from [fit_model()])
#' @param data Data list (from [prepare_data()])
#' @param param character. Name of the parameter to retrieve the posterior samples.
#'
#' @return A data frame
#' @export
#'
#' @examplesIf interactive()
#' data(web)
#' dt <- prepare_data(mat = web, sampl.eff = rep(20, nrow(web)))
#' fit <- fit_model(dt, refresh = 0)
#' get_posterior(fit, dt, param = "connectance")
#'
#' int.prob <- get_posterior(fit, dt, param = "int.prob")
#' int.prob
#' int.prob |> tidybayes::mean_qi()  # mean edge probability
#'
#' # all posteriors
#' get_posterior(fit, dt, param = "all")

get_posterior <- function(fit = NULL,
                          data = NULL,
                          param = c("all",
                                    "connectance",
                                    "preference",
                                    "plant.abund",
                                    "animal.abund",
                                    "int.prob",
                                    "link")) {

  # r = avg. visits from mutualists (preference)
  # rho = connectance
  # sigma = plant.abund
  # tau = animal.abund
  # Q = interaction probability

  param <- match.arg(param)

  params_all <- function(fit) {
    if (fit$metadata()$model_name == "varying_preferences_model") {
      out <- tidybayes::spread_draws(fit, rho, r[Animal], sigma[Plant], tau[Animal], Q[Plant, Animal])
    } else {
      out <- tidybayes::spread_draws(fit, rho, r, sigma[Plant], tau[Animal], Q[Plant, Animal])
    }
    return(out)
  }

  params_preference <- function(fit) {
    if (fit$metadata()$model_name == "varying_preferences_model") {
      out <- tidybayes::spread_draws(fit, r[Animal])
    } else {
      out <- tidybayes::spread_draws(fit, r)
    }
    return(out)
  }


  post <- switch(
    param,
    all = params_all(fit),
    connectance = tidybayes::spread_draws(fit, rho),
    preference = params_preference(fit),
    plant.abund = tidybayes::spread_draws(fit, sigma[Plant]),
    animal.abund = tidybayes::spread_draws(fit, tau[Animal]),
    int.prob = tidybayes::spread_draws(fit, Q[Plant, Animal]),
    link = tidybayes::spread_draws(fit, Q[Plant, Animal]),
  )

  # use more informative names
  param.names <- c(
    connectance = "rho",
    preference = "r",
    plant.abund = "sigma",
    animal.abund = "tau",
    int.prob = "Q")

  post <- dplyr::rename(post, dplyr::any_of(param.names))

  ## generate posteriors of link existence
  if (param == "all" | param == "link") {
    post <- is_there_link(post)
  }



  ## rename plants and animals with original labels

  if ("Animal" %in% names(post)) {
    animals <- data.frame(Animal = 1:ncol(data$M), Animal.name = colnames(data$M))
    post <- post |>
      dplyr::mutate(Animal = animals$Animal.name[match(Animal, animals$Animal)]) |>
      dplyr::relocate(Animal)
  }

  if ("Plant" %in% names(post)) {
    plants <- data.frame(Plant = 1:nrow(data$M), Plant.name = rownames(data$M))
    post <- post |>
      dplyr::mutate(Plant = plants$Plant.name[match(Plant, plants$Plant)]) |>
      dplyr::relocate(Plant)
  }

  return(post)


}
