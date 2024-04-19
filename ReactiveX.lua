if Debug then Debug.beginFile "ReactiveX" end
OnInit.module("ReactiveX", function(require)
    -- RxLua v0.0.3
    -- https://github.com/bjornbytes/rxlua
    -- MIT License

    -- modified by Insanity_AI:
    -- changed to use EmmyLua annotations
    -- separated into multiple modules using TotalInitialization as driver
    -- utilized TimerQueue as scheduler implementations

    -- To understand the purpose of this library, it's best to check out its modules in the following order:
    -- For more info check out https://reactivex.io/

    require "ReactiveX/Util"

    require "ReactiveX/Observer" ---@type Observer
    require "ReactiveX/Observable" ---@type Observable
    require "ReactiveX/Subscription" ---@type Subscription

    require "ReactiveX/Scheduler/ImmediateScheduler" ---@type ImmediateScheduler
    require "ReactiveX/Scheduler/TimeoutScheduler" ---@type TimeoutScheduler
    require "ReactiveX/Scheduler/CooperativeScheduler" ---@type CooperativeScheduler

    require "ReactiveX/Subject/Subject" ---@type Subject
    require "ReactiveX/Subject/AsyncSubject" ---@type AsyncSubject
    require "ReactiveX/Subject/BehaviorSubject" ---@type BehaviorSubject
    require "ReactiveX/Subject/ReplaySubject" ---@type ReplaySubject
end)
if Debug then Debug.endFile() end
