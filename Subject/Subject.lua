if Debug then Debug.beginFile "ReactiveX/Subject" end
OnInit.module("ReactiveX/Subject/Subject", function(require)
    require "ReactiveX/Util"
    require "ReactiveX/Observable"
    require "ReactiveX/Observer"

    --- @class Subject : Observer, Observable
    --- @field observers Observer[]
    -- Subjects function both as an Observer and as an Observable. Subjects inherit all
    -- Observable functions, including subscribe. Values can also be pushed to the Subject, which will
    -- be broadcasted to any subscribed Observers.
    Subject = setmetatable({}, Observable)
    Subject.__index = Subject
    Subject.__tostring = ReactiveXUtil.constant('Subject')

    --- Creates a new Subject.
    --- @return Subject
    function Subject.create()
        return setmetatable({
            observers = {},
            stopped = false
        }, Subject) --[[@as Subject]]
    end

    --- Creates a new Observer and attaches it to the Subject.
    --- @param onNext fun(...)|Observer - A function called when the Subject produces a value or an existing Observer to attach to the Subject.
    --- @param onError function? - Called when the Subject terminates due to an error.
    --- @param onCompleted function? - Called when the Subject completes normally.
    function Subject:subscribe(onNext, onError, onCompleted)
        local observer

        if ReactiveXUtil.isa(onNext, Observer) then
            observer = onNext
        else
            observer = Observer.create(onNext --[[@as fun(...)]], onError, onCompleted)
        end

        table.insert(self.observers, observer)

        return Subscription.create(function()
            for i = 1, #self.observers do
                if self.observers[i] == observer then
                    table.remove(self.observers, i)
                    return
                end
            end
        end)
    end

    --- Pushes zero or more values to the Subject. They will be broadcasted to all Observers.
    --- @param ... any
    function Subject:onNext(...)
        if not self.stopped then
            for i = #self.observers, 1, -1 do
                self.observers[i]:onNext(...)
            end
        end
    end

    --- Signal to all Observers that an error has occurred.
    --- @param message string - A string describing what went wrong.
    function Subject:onError(message)
        if not self.stopped then
            for i = #self.observers, 1, -1 do
                self.observers[i]:onError(message)
            end

            self.stopped = true
        end
    end

    --- Signal to all Observers that the Subject will not produce any more values.
    function Subject:onCompleted()
        if not self.stopped then
            for i = #self.observers, 1, -1 do
                self.observers[i]:onCompleted()
            end

            self.stopped = true
        end
    end

    Subject.__call = Subject.onNext

    return Subject
end)
if Debug then Debug.endFile() end