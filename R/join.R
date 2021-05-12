# TODO: `by` for groups
# TODO: `type` should be able to take a "limit" integer
# TODO: Finer control over rolling the ends? Like `rollends`
# TODO: Allow `i` to be different between `x` and `y`? c("foo" = "bar")?

slide_join <- function(x, y, i, ..., type = "locf") {
  check_dots_empty()

  x_i <- x[[i]]
  y_i <- y[[i]]

  y[[i]] <- NULL

  x_size <- vec_size(x)
  y_size <- vec_size(y)

  y_front <- min(1L, y_size)
  y_back <- y_size

  y_empty <- y_size == 0L

  if (identical(type, "locf")) {
    from <- vec_slice(y_i, -y_back)
    to <- vec_slice(y_i, -y_front)

    # Hack, need `hop_index(.bounds = "[)")`, then we wouldn't do `to - 1L`
    to <- to - 1L
    to <- pmax(to, from)

    if (y_empty) {
      x_slicer_before <- seq_len(x_size)
      x_slicer_after <- integer()
    } else {
      x_slicer_before <- which(x_i < vec_slice(y_i, y_front))
      x_slicer_after <- which(x_i >= vec_slice(y_i, y_back))
    }

    y_slicer_before <- vec_rep(NA_integer_, length(x_slicer_before))
    y_slicer_after <- vec_rep(y_back, length(x_slicer_after))

    y_slicer_start <- y_front
    y_slicer_stop <- y_back - 1L
  } else if (identical(type, "nocb")) {
    to <- vec_slice(y_i, -y_front)
    from <- vec_slice(y_i, -y_back)

    # Hack, need `hop_index(.bounds = "(]")`, then we wouldn't do `from + 1L`
    # maybe (]? Not sure, but matches <=, > used in slicers
    from <- from + 1L
    from <- pmin(from, to)

    if (y_empty) {
      x_slicer_before <- integer()
      x_slicer_after <- seq_len(x_size)
    } else {
      x_slicer_before <- which(x_i <= vec_slice(y_i, y_front))
      x_slicer_after <- which(x_i > vec_slice(y_i, y_back))
    }

    y_slicer_before <- vec_rep(y_front, length(x_slicer_before))
    y_slicer_after <- vec_rep(NA_integer_, length(x_slicer_after))

    y_slicer_start <- y_front + 1L
    y_slicer_stop <- y_back
  } else {
    abort("Invalid `type`.")
  }

  locs_list <- slider::hop_index(
    .x = seq_len(x_size),
    .i = x_i,
    .starts = from,
    .stops = to,
    .f = identity
  )

  x_slicer <- unlist(locs_list, recursive = FALSE, use.names = FALSE)
  y_slicer <- vec_rep_each(seq2(y_slicer_start, y_slicer_stop), lengths(locs_list))

  x_slicer <- c(x_slicer_before, x_slicer, x_slicer_after)
  y_slicer <- c(y_slicer_before, y_slicer, y_slicer_after)

  x_out <- vec_slice(x, x_slicer)
  y_out <- vec_slice(y, y_slicer)

  i_out <- x_out[, i, drop = FALSE]
  x_out[[i]] <- NULL

  # Probably needs to pass through names handling
  vec_cbind(
    x_out,
    i_out,
    y_out
  )
}

slide_left_join <- function(x, y, i, by, ..., type = "locf") {
  check_dots_empty()

  by_syms <- syms(by)

  joined <- dplyr::left_join(
    dplyr::nest_by(x, !!!by_syms, .key = "lhs"),
    dplyr::nest_by(y, !!!by_syms, .key = "rhs"),
    by = by
  )

  joined$lhs[vec_equal_na(joined$lhs)] <- list(attr(joined$lhs, "ptype"))
  joined$rhs[vec_equal_na(joined$rhs)] <- list(attr(joined$rhs, "ptype"))

  dplyr::summarise(
    joined,
    slide_join(x = lhs, y = rhs, i = i, type = type),
    .groups = "keep"
  )
}

slide_right_join <- function(x, y, i, by, ..., type = "locf") {
  check_dots_empty()

  by_syms <- syms(by)

  joined <- dplyr::right_join(
    dplyr::nest_by(x, !!!by_syms, .key = "lhs"),
    dplyr::nest_by(y, !!!by_syms, .key = "rhs"),
    by = by
  )

  joined$lhs[vec_equal_na(joined$lhs)] <- list(attr(joined$lhs, "ptype"))
  joined$rhs[vec_equal_na(joined$rhs)] <- list(attr(joined$rhs, "ptype"))

  dplyr::summarise(
    joined,
    slide_join(x = lhs, y = rhs, i = i, type = type),
    .groups = "keep"
  )
}

slide_inner_join <- function(x, y, i, by, ..., type = "locf") {
  check_dots_empty()

  by_syms <- syms(by)

  joined <- dplyr::inner_join(
    dplyr::nest_by(x, !!!by_syms, .key = "lhs"),
    dplyr::nest_by(y, !!!by_syms, .key = "rhs"),
    by = by
  )

  joined$lhs[vec_equal_na(joined$lhs)] <- list(attr(joined$lhs, "ptype"))
  joined$rhs[vec_equal_na(joined$rhs)] <- list(attr(joined$rhs, "ptype"))

  dplyr::summarise(
    joined,
    slide_join(x = lhs, y = rhs, i = i, type = type),
    .groups = "keep"
  )
}
