{...}: {
  # Keep Spotify's renderer on GPU paths so WebGL2 remains available.
  # If Spotify still starts with a broken WebGL stack on a specific launch,
  # add temporary launch flags there instead of forcing --disable-gpu globally.
}
