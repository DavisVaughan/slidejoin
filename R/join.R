# TODO: `by` for groups
# TODO: `type` should be able to take a "limit" integer
# TODO: Finer control over rolling the ends? Like `rollends`
# TODO: Allow `i` to be different between `x` and `y`? c("foo" = "bar")?

slide_join <- function(x, y, i, ..., type = "locf") {
  check_dots_empty()

  x_i <- x[[i]]
  y_i <- y[[i]]

  x[[i]] <- NULL

  x_size <- vec_size(x)
  y_size <- vec_size(y)

  x_front <- min(1L, x_size)
  x_back <- x_size

  x_empty <- x_size == 0L

  if (identical(type, "locf")) {
    from <- vec_slice(x_i, -x_back)
    to <- vec_slice(x_i, -x_front)

    # Hack, need `hop_index(.bounds = "[)")`, then we wouldn't do `to - 1L`
    to <- to - 1L
    to <- pmax(to, from)

    if (x_empty) {
      y_slicer_before <- seq_len(y_size)
      y_slicer_after <- integer()
    } else {
      y_slicer_before <- which(y_i < vec_slice(x_i, x_front))
      y_slicer_after <- which(y_i >= vec_slice(x_i, x_back))
    }

    x_slicer_before <- vec_rep(NA_integer_, length(y_slicer_before))
    x_slicer_after <- vec_rep(x_back, length(y_slicer_after))

    x_slicer_start <- x_front
    x_slicer_stop <- x_back - 1L
  } else if (identical(type, "nocb")) {
    to <- vec_slice(x_i, -x_front)
    from <- vec_slice(x_i, -x_back)

    # Hack, need `hop_index(.bounds = "(]")`, then we wouldn't do `from + 1L`
    # maybe (]? Not sure, but matches <=, > used in slicers
    from <- from + 1L
    from <- pmin(from, to)

    if (x_empty) {
      y_slicer_before <- integer()
      y_slicer_after <- seq_len(y_size)
    } else {
      y_slicer_before <- which(y_i <= vec_slice(x_i, x_front))
      y_slicer_after <- which(y_i > vec_slice(x_i, x_back))
    }

    x_slicer_before <- vec_rep(x_front, length(y_slicer_before))
    x_slicer_after <- vec_rep(NA_integer_, length(y_slicer_after))

    x_slicer_start <- x_front + 1L
    x_slicer_stop <- x_back
  } else {
    abort("Invalid `type`.")
  }

  locs_list <- slider::hop_index(
    .x = seq_len(y_size),
    .i = y_i,
    .starts = from,
    .stops = to,
    .f = identity
  )

  x_slicer <- vec_rep_each(seq2(x_slicer_start, x_slicer_stop), lengths(locs_list))
  y_slicer <- unlist(locs_list, recursive = FALSE, use.names = FALSE)

  x_slicer <- c(x_slicer_before, x_slicer, x_slicer_after)
  y_slicer <- c(y_slicer_before, y_slicer, y_slicer_after)

  x_out <- vec_slice(x, x_slicer)
  y_out <- vec_slice(y, y_slicer)

  i_out <- y_out[, i, drop = FALSE]
  y_out[[i]] <- NULL

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
