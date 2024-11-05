if Debug then Debug.beginFile "TimerQueueSubscription" end
OnInit.module("TimerQueueSubscription", function(require)
    require "ReactiveX/Util"
    require "ReactiveX/Subscription"

    -- A subscription wrapper for TimerQueueTask
    ---@class TimerQueueSubscription: Subscription
    ---@field scheduler Scheduler
    ---@field timerQueueTask TimerQueueElement
    TimerQueueSubscription = {}
    TimerQueueSubscription.__index = TimerQueueSubscription
    TimerQueueSubscription.__tostring = ReactiveXUtil.constant("TimerQueueSubscription")

    -- Creates a new Subscription.
    ---@param scheduler Scheduler
    ---@param timerQueueTask TimerQueueElement
    ---@return TimerQueueSubscription
    function TimerQueueSubscription.create(scheduler, timerQueueTask)
        local instance = setmetatable(Subscription.create(), TimerQueueSubscription)
        instance.scheduler = scheduler
        instance.timerQueueTask = timerQueueTask
        return instance --[[@as TimerQueueSubscription]]
    end

    --- Unsubscribes the subscription, performing any necessary cleanup work.
    function TimerQueueSubscription:unsubscribe()
        if self.unsubscribed then return end
        self.scheduler:unschedule(self)
        self.unsubscribed = true
    end

    return TimerQueueSubscription
end)
if Debug then Debug.endFile() end