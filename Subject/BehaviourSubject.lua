if Debug then Debug.beginFile "ReactiveX/BehaviorSubject" end
OnInit.module("ReactiveX/Subject/BehaviorSubject", function(require)
    require "ReactiveX/Util"
    require "ReactiveX/Observable"
    require "ReactiveX/Observer"
    require "ReactiveX/Subject/Subject"

    --- @class BehaviorSubject : Subject
    -- @description A Subject that tracks its current value. Provides an accessor to retrieve the most
    -- recent pushed value, and all subscribers immediately receive the latest value.
    BehaviorSubject = setmetatable({}, Subject)
    BehaviorSubject.__index = BehaviorSubject
    BehaviorSubject.__tostring = ReactiveXUtil.constant('BehaviorSubject')

    --- Creates a new BehaviorSubject.
    --- @param ... any - The initial values.
    --- @return BehaviorSubject
    function BehaviorSubject.create(...)
        local self = {
            observers = {},
            stopped = false
        }

        if select('#', ...) > 0 then
            self.value = ReactiveXUtil.pack(...)
        end

        return setmetatable(self, BehaviorSubject) --[[@as BehaviorSubject]]
    end

    --- Creates a new Observer and attaches it to the BehaviorSubject. Immediately broadcasts the most
    -- recent value to the Observer.
    --- @param onNext function - Called when the BehaviorSubject produces a value.
    --- @param onError function - Called when the BehaviorSubject terminates due to an error.
    --- @param onCompleted function - Called when the BehaviorSubject completes normally.
    function BehaviorSubject:subscribe(onNext, onError, onCompleted)
        local observer

        if ReactiveXUtil.isa(onNext, Observer) then
            observer = onNext
        else
            observer = Observer.create(onNext, onError, onCompleted)
        end

        local subscription = Subject.subscribe(self, observer)

        if self.value then
            observer:onNext(ReactiveXUtil.unpack(self.value))
        end

        return subscription
    end

    --- Pushes zero or more values to the BehaviorSubject. They will be broadcasted to all Observers.
    --- @param ... any
    function BehaviorSubject:onNext(...)
        self.value = ReactiveXUtil.pack(...)
        return Subject.onNext(self, ...)
    end

    --- Returns the last value emitted by the BehaviorSubject, or the initial value passed to the
    -- constructor if nothing has been emitted yet.
    --- @return any
    function BehaviorSubject:getValue()
        if self.value ~= nil then
            return ReactiveXUtil.unpack(self.value)
        end
    end

    BehaviorSubject.__call = BehaviorSubject.onNext

    return BehaviorSubject
end)
if Debug then Debug.endFile() end