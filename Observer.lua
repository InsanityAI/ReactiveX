if Debug then Debug.beginFile "ReactiveX/Observer" end
OnInit.module("ReactiveX.Observer", function(require)
    require "ReactiveX.Util"

    --- @class Observer
    --- @field _onNext fun(values: ...)
    --- @field _onError fun(message: any, level: integer?)
    --- @field _onCompleted fun()
    --- @field stopped boolean
    -- Observers are simple objects that receive values from Observables.
    Observer = {}
    Observer.__index = Observer
    Observer.__tostring = ReactiveXUtil.constant('Observer')

    --- Creates a new Observer.
    --- @param onNext? fun(...) Called when the Observable produces a value.
    --- @param onError? fun(message: string) Called when the Observable terminates due to an error.
    --- @param onCompleted? fun() Called when the Observable completes normally.
    --- @return Observer
    function Observer.create(onNext, onError, onCompleted)
        return setmetatable({
            _onNext = onNext or ReactiveXUtil.noop,
            _onError = onError or error,
            _onCompleted = onCompleted or ReactiveXUtil.noop,
            stopped = false
        }, Observer)
    end

    --- Pushes zero or more values to the Observer.
    --- @param ... any
    function Observer:onNext(...)
        if not self.stopped then
            self._onNext(...)
        end
    end

    --- Notify the Observer that an error has occurred.
    --- @param message string A string describing what went wrong.
    function Observer:onError(message)
        if not self.stopped then
            self.stopped = true
            self._onError(message)
        end
    end

    --- Notify the Observer that the sequence has completed and will produce no more values.
    function Observer:onCompleted()
        if not self.stopped then
            self.stopped = true
            self._onCompleted()
        end
    end

    return Observer
end)
if Debug then Debug.endFile() end