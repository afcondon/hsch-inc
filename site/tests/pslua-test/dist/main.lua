local M = {}
M.Main_Green = { ["$ctor"] = "Main∷Color.Green" }
M.Main_colorToNumber = function(v)
  if "Main∷Color.Red" == v["$ctor"] then
    return 1
  else
    if "Main∷Color.Green" == v["$ctor"] then
      return 2
    else
      if "Main∷Color.Blue" == v["$ctor"] then
        return 3
      else
        return error("No patterns matched")
      end
    end
  end
end
return {
  Red = { ["$ctor"] = "Main∷Color.Red" },
  Green = M.Main_Green,
  Blue = { ["$ctor"] = "Main∷Color.Blue" },
  colorToNumber = M.Main_colorToNumber,
  getName = function(p) return p.name end,
  main = M.Main_colorToNumber(M.Main_Green)
}