if Debug then Debug.beginFile "ReactiveX/Scheduler/Scheduler" end
OnInit.module("ReactiveX.Scheduler.Scheduler", function(require)
    require.optional "TimerQueue"
    require "TimerQueueSubscription"

    ---@class Scheduler
    ---@field defaultDelay number
    ---@field schedule fun(self: Scheduler, action: function, delay?: number): Subscription
    ---@field unschedule fun(self: Scheduler, subscription: Subscription)

    if Debug and not TimerQueue then Debug.log("TimerQueue not found, Scheduler usage will cause errors.") end

end)
if Debug then Debug.endFile() end
