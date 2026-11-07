local public = {}

public.mod_name = "energy-combinator-21-enhanced"
public.mod_short_name = ""
public.prototype_prefix = public.mod_short_name ~= "" and public.mod_short_name .. "-" or ""
public.mod_root = "__" .. public.mod_name .. "__/"
public.mod_locale = public.mod_short_name ~= "" and public.mod_short_name .. "."
public.graphics_path = public.mod_root .. "graphics/"

return public
