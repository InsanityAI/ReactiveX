if Debug then Debug.beginFile "ReactiveX/Scheduler/TimeoutScheduler" end
OnInit.module("ReactiveX/Scheduler/TimeoutScheduler", function(require)
    require "ReactiveX/Util"
    require.optional "TimerQueue"
    require "TimerQueueSubscription"
    require "ReactiveX/Scheduler/Scheduler"

    --- @class TimeoutScheduler: Scheduler
    --- @field defaultDelay number
    --- @field timerQueue TimerQueue
    --- @description A scheduler that uses TimerQueue library
    TimeoutScheduler = {}
    TimeoutScheduler.__index = TimeoutScheduler
    TimeoutScheduler.__tostring = ReactiveXUtil.constant('TimeoutScheduler')

    --- Creates a new TimeoutScheduler.
    --- @param defaultDelay number
    --- @return TimeoutScheduler
    function TimeoutScheduler.create(defaultDelay)
        return setmetatable({
            defaultDelay = defaultDelay,
            timerQueue = TimerQueue.create(),
        }, TimeoutScheduler)
    end

    --- Schedules an action to run at a future point in time.
    --- @param action function - The action to run.
    --- @param delay? number - The delay, in seconds
    --- @return TimerQueueSubscription
    function TimeoutScheduler:schedule(action, delay, ...)
        return TimerQueueSubscription.create(self, self.timerQueue:callDelayed(delay or self.defaultDelay, action))
    end

    ---@param task TimerQueueSubscription
    function TimeoutScheduler:unschedule(task)
        self.timerQueue:cancel(task.timerQueueTask)
    end

    return TimeoutScheduler
end)
if Debug then Debug.endFile() end
