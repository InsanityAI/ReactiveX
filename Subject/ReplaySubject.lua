if Debug then Debug.beginFile "ReactiveX/ReplaySubject" end
OnInit.module("ReactiveX/Subject/ReplaySubject", function(require)
    require "ReactiveX/Util"
    require "ReactiveX/Observable"
    require "ReactiveX/Observer"
    require "ReactiveX/Subject/Subject"

    --- @class ReplaySubject : Subject
    --- @field buffer any[]
    --- @field bufferSize integer
    -- @description A Subject that provides new Subscribers with some or all of the most recently
    -- produced values upon subscription.
    ReplaySubject = setmetatable({}, Subject)
    ReplaySubject.__index = ReplaySubject
    ReplaySubject.__tostring = ReactiveXUtil.constant('ReplaySubject')

    --- Creates a new ReplaySubject.
    --- @param bufferSize number - The number of values to send to new subscribers. If nil, an infinite buffer is used (note that this could lead to memory issues).
    --- @return ReplaySubject
    function ReplaySubject.create(bufferSize)
        local self = {
            observers = {},
            stopped = false,
            buffer = {},
            bufferSize = bufferSize
        }

        return setmetatable(self, ReplaySubject) --[[@as ReplaySubject]]
    end

    --- Creates a new Observer and attaches it to the ReplaySubject. Immediately broadcasts the most
    -- contents of the buffer to the Observer.
    --- @param onNext function - Called when the ReplaySubject produces a value.
    --- @param onError function - Called when the ReplaySubject terminates due to an error.
    --- @param onCompleted function - Called when the ReplaySubject completes normally.
    function ReplaySubject:subscribe(onNext, onError, onCompleted)
        local observer

        if ReactiveXUtil.isa(onNext, Observer) then
            observer = onNext
        else
            observer = Observer.create(onNext, onError, onCompleted)
        end

        local subscription = Subject.subscribe(self, observer)

        for i = 1, #self.buffer do
            observer:onNext(ReactiveXUtil.unpack(self.buffer[i]))
        end

        return subscription
    end

    --- Pushes zero or more values to the ReplaySubject. They will be broadcasted to all Observers.
    --- @param ... any
    function ReplaySubject:onNext(...)
        table.insert(self.buffer, ReactiveXUtil.pack(...))
        if self.bufferSize and #self.buffer > self.bufferSize then
            table.remove(self.buffer, 1)
        end

        return Subject.onNext(self, ...)
    end

    ReplaySubject.__call = ReplaySubject.onNext

    return ReplaySubject
end)
if Debug then Debug.endFile() end