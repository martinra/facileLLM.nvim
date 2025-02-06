local log = require("structlog")


log.configure({
  facilellm = {
    pipelines = {
      {
        level = log.level.INFO,
        processors = {
          log.processors.Timestamper("%H:%M:%S"),
        },
        formatter = log.formatters.Format(
          "%s [%s] %s: %-30s",
          { "timestamp", "level", "logger_name", "msg" }
        ),
        sink = log.sinks.File("./facilellm.log"),
      },
    },
  },
})


local get_logger = function ()
  return log.get_logger("facilellm")
end


return {
  get_logger = get_logger,
}
