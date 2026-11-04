// auto-generated. feature order: domfreq, bp_4_6, bp_3_12, bp_low, rms_acc, p2p_acc, rms_gyr, conc
// classes: rest, tremor, voluntary
inline int predict_tree(const float* x) {
  if (x[1] < 0.001203668f) {
    return 0;  // rest
  } else {
    if (x[6] < 29.56569f) {
      return 2;  // voluntary
    } else {
      return 1;  // tremor
    }
  }
}
