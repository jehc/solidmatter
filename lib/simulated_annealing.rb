#!/usr/bin/env ruby
#
#  Created by Björn Breitgoff on 17-04-09.
#  Copyright (c) 2008. All rights reserved.


def anneal( part, dim, min, max, target_fos, decrement)
  t = max - min
  best_value = (max + min) / 2.0
  best_fos = $fem.solve(part)
  while t > decrement
    cut_min = [min, best_value - t/2].max
    cut_max = [max, best_value + t/2].min
    span = cut_max - cut_min
    sample = cut_min + rand*span
    dim.value = sample
    part.build dim.sketch.parent
    fos = $fem.solve(part)
    if (fos - target_fos).abs < (best_fos - taget_fos).abs
      best_fos = fos
      best_value = sample
    end
    t -= decrement
  end
end

