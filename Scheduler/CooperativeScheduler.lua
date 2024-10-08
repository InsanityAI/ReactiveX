---@diagnostic disable: deprecated
if Debug then Debug.beginFile "ReactiveX/Scheduler/CooperativeScheduler" end
OnInit.module("ReactiveX/Scheduler/CooperativeScheduler", function(require)
    require "ReactiveX/Util"
    require "ReactiveX/Scheduler/Scheduler"

    --- @deprecated this is some weird form of PolledWait shenanigans, yuck
    --- @class CooperativeScheduler: Scheduler
    --- @field tasks {thread: thread, due: number}[]
    -- @description Manages Observables using coroutines and a virtual clock that must be updated
    -- manually.
    CooperativeScheduler = {}
    CooperativeScheduler.__index = CooperativeScheduler
    CooperativeScheduler.__tostring = ReactiveXUtil.constant('CooperativeScheduler')

    --- Creates a new CooperativeScheduler.
    --- @param currentTime number - A time to start the scheduler at.
    --- @return CooperativeScheduler
    function CooperativeScheduler.create(currentTime)
        local self = {
            tasks = {},
            currentTime = currentTime or 0
        }

        return setmetatable(self, CooperativeScheduler)
    end

    --- Schedules a function to be run after an optional delay.  Returns a subscription that will stop
    -- the action from running.
    --- @param action function - The function to execute. Will be converted into a coroutine. The coroutine may yield execution back to the scheduler with an optional number, which will put it to sleep for a time period.
    --- @param delay number - Delay execution of the action by a virtual time period.
    --- @return Subscription
    function CooperativeScheduler:schedule(action, delay)
        local task = {
            thread = coroutine.create(action),
            due = self.currentTime + (delay or 0)
        }

        table.insert(self.tasks, task)

        return Subscription.create(function()
            return self:unschedule(task)
        end)
    end

    function CooperativeScheduler:unschedule(task)
        for i = 1, #self.tasks do
            if self.tasks[i] == task then
                table.remove(self.tasks, i)
            end
        end
    end

    --- Triggers an update of the CooperativeScheduler. The clock will be advanced and the scheduler
    -- will run any coroutines that are due to be run.
    --- @param delta number - An amount of time to advance the clock by. It is common to pass in the time in seconds or milliseconds elapsed since this function was last called.
    function CooperativeScheduler:update(delta)
        self.currentTime = self.currentTime + (delta or 0)

        local i = 1
        while i <= #self.tasks do
            local task = self.tasks[i]

            if self.currentTime >= task.due then
                local success, delay = coroutine.resume(task.thread)

                if coroutine.status(task.thread) == 'dead' then
                    table.remove(self.tasks, i)
                else
                    task.due = math.max(task.due + (delay or 0), self.currentTime)
                    i = i + 1
                end

                if not success then
                    error(delay)
                end
            else
                i = i + 1
            end
        end
    end

    --- Returns whether or not the CooperativeScheduler's queue is empty.
    function CooperativeScheduler:isEmpty()
        return not next(self.tasks)
    end

    return CooperativeScheduler
end)
if Debug then Debug.endFile() end