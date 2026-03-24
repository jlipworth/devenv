local raw_packages = vim.env.CI_MASON_PACKAGES or ""
local timeout_ms = tonumber(vim.env.CI_MASON_TIMEOUT_MS or "180000")

local packages = {}
for pkg in string.gmatch(raw_packages, "([^,]+)") do
  table.insert(packages, pkg)
end

if #packages == 0 then
  error("CI_MASON_PACKAGES is empty")
end

local base = vim.fn.stdpath("data") .. "/mason/packages/"
local deadline = vim.loop.now() + timeout_ms

local function missing_packages()
  local missing = {}
  for _, pkg in ipairs(packages) do
    if vim.fn.isdirectory(base .. pkg) == 0 then
      table.insert(missing, pkg)
    end
  end
  return missing
end

local missing = missing_packages()
while #missing > 0 do
  if vim.loop.now() > deadline then
    error("Timed out waiting for Mason packages: " .. table.concat(missing, ", "))
  end
  vim.cmd("sleep 1000m")
  missing = missing_packages()
end
