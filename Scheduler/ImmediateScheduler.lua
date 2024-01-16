if Debug then Debug.beginFile "ReactiveX/Scheduler/ImmediateScheduler" end
OnInit.module("ReactiveX.Scheduler.ImmediateScheduler", function(require)
    require "ReactiveX.Util"
    require "ReactiveX.Scheduler.Scheduler"

    --- @class ImmediateScheduler: Scheduler
    --- @description Schedules Observables by running all operations immediately.
    ImmediateScheduler = {}
    ImmediateScheduler.__index = ImmediateScheduler
    ImmediateScheduler.__tostring = ReactiveXUtil.constant('ImmediateScheduler')

    --- Creates a new ImmediateScheduler.
    --- @return ImmediateScheduler}
    function ImmediateScheduler.create()
        return setmetatable({}, ImmediateScheduler)
    end

    --- Schedules a function to be run on the scheduler. It is executed immediately.
    --- @param action function - The function to execute.
    function ImmediateScheduler:schedule(action)
        action()
    end

    ImmediateScheduler.unschedule = ReactiveXUtil.noop

    return ImmediateScheduler
end)
if Debug then Debug.endFile() end