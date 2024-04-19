if Debug then Debug.beginFile "ReactiveX/Observable" end
OnInit.module("ReactiveX/Observable", function(require)
    require "ReactiveX/Util"

    --- @class Observable
    --- @field _subscribe fun(observer: Observer): Subscription
    -- Observables push values to Observers.
    Observable = {}
    Observable.__index = Observable
    Observable.__tostring = ReactiveXUtil.constant('Observable')

    --- Creates a new Observable.
    --- @param subscribe fun(observer: Observer): Subscription? The subscription function that produces values.
    --- @return Observable
    function Observable.create(subscribe)
        local self = {
            _subscribe = subscribe
        }

        return setmetatable(self, Observable)
    end

    --- Shorthand for creating an Observer and passing it to this Observable's subscription function.
    --- @param onNext? table|fun(...) Called when the Observable produces a value.
    --- @param onError? fun(message: string) Called when the Observable terminates due to an error.
    --- @param onCompleted? fun() Called when the Observable completes normally.
    --- @return Subscription
    function Observable:subscribe(onNext, onError, onCompleted)
        if type(onNext) == 'table' then
            return self._subscribe(onNext)
        else
            return self._subscribe(Observer.create(onNext, onError, onCompleted))
        end
    end

    --- Returns an Observable that immediately completes without producing a value.
    function Observable.empty()
        ---@param observer Observer
        return Observable.create(function(observer)
            observer:onCompleted()
        end)
    end

    --- Returns an Observable that never produces values and never completes.
    function Observable.never()
        return Observable.create(function(observer) end)
    end

    --- Returns an Observable that immediately produces an error.
    --- @param message string
    function Observable.throw(message)
        --- @param observer Observer
        return Observable.create(function(observer)
            observer:onError(message)
        end)
    end

    --- Creates an Observable that produces a set of values.
    --- @param ... any
    --- @return Observable
    function Observable.of(...)
        local args = { ... }
        local argCount = select('#', ...)
        return Observable.create(function(observer)
            for i = 1, argCount do
                observer:onNext(args[i])
            end

            observer:onCompleted()
        end)
    end

    --- Creates an Observable that produces a range of values in a manner similar to a Lua for loop.
    --- @param initial integer The first value of the range, or the upper limit if no other arguments are specified.
    --- @param limit integer The second value of the range.
    --- @param step integer An amount to increment the value by each iteration.
    --- @return Observable
    function Observable.fromRange(initial, limit, step)
        if not limit and not step then
            initial, limit = 1, initial
        end

        step = step or 1

        return Observable.create(function(observer)
            for i = initial, limit, step do
                observer:onNext(i)
            end

            observer:onCompleted()
        end)
    end

    --- Creates an Observable that produces values from a table.
    --- @generic K, V
    --- @param t table The table used to create the Observable.
    --- @param iterator fun(table: table<K, V>, index?: K):K, V An iterator used to iterate the table, e.g. pairs or ipairs.
    --- @param keys boolean Whether or not to also emit the keys of the table.
    --- @return Observable
    function Observable.fromTable(t, iterator, keys)
        iterator = iterator or pairs
        ---@param observer Observer
        return Observable.create(function(observer)
            for key, value in iterator(t) do
                observer:onNext(value, keys and key or nil)
            end

            observer:onCompleted()
        end)
    end

    --- Creates an Observable that produces values when the specified coroutine yields.
    --- @param fn thread|function A coroutine or function to use to generate values.  Note that if a coroutine is used, the values it yields will be shared by all subscribed Observers (influenced by the Scheduler), whereas a new coroutine will be created for each Observer when a function is used.
    ---@param scheduler Scheduler
    --- @return Observable
    function Observable.fromCoroutine(fn, scheduler)
        return Observable.create(function(observer)
            local thread = type(fn) == 'function' and coroutine.create(fn) or fn
            return scheduler:schedule(function()
                while not observer.stopped do
                    local success, value = coroutine.resume(thread --[[@as thread]])

                    if success then
                        observer:onNext(value)
                    else
                        return observer:onError(value)
                    end

                    if coroutine.status(thread --[[@as thread]]) == 'dead' then
                        return observer:onCompleted()
                    end

                    coroutine.yield()
                end
            end)
        end)
    end

    --- Creates an Observable that creates a new Observable for each observer using a factory function.
    --- @param fn fun():Observable A function that returns an Observable.
    --- @return Observable
    function Observable.defer(fn)
        if not fn or type(fn) ~= 'function' then
            error('Expected a function')
        end

        return setmetatable({
            subscribe = function(_, ...)
                local observable = fn()
                return observable:subscribe(...)
            end
        }, Observable)
    end

    --- Returns an Observable that repeats a value a specified number of times.
    --- @param value any - The value to repeat.
    --- @param count number - The number of times to repeat the value.  If left unspecified, the value is repeated an infinite number of times.
    --- @return Observable
    function Observable.replicate(value, count)
        return Observable.create(function(observer)
            while count == nil or count > 0 do
                observer:onNext(value)
                if count then
                    count = count - 1
                end
            end
            observer:onCompleted()
        end)
    end

    --- Subscribes to this Observable and prints values it produces.
    --- @param name string - Prefixes the printed messages with a name.
    --- @param formatter function - A function that formats one or more values to be printed. Default is toString
    function Observable:dump(name, formatter)
        name = name and (name .. ' ') or ''
        formatter = formatter or tostring

        local onNext = function(...) print(name .. 'onNext: ' .. formatter(...)) end
        local onError = function(e) print(name .. 'onError: ' .. e) end
        local onCompleted = function() print(name .. 'onCompleted') end

        return self:subscribe(onNext, onError, onCompleted)
    end

    --- Determine whether all items emitted by an Observable meet some criteria.
    --- @param predicate fun(x: any): any - The predicate used to evaluate objects. Default is util.identity
    function Observable:all(predicate)
        predicate = predicate or ReactiveXUtil.identity

        return Observable.create(function(observer)
            local function onNext(...)
                ReactiveXUtil.tryWithObserver(observer, function(...)
                    if not predicate(...) then
                        observer:onNext(false)
                        observer:onCompleted()
                    end
                end, ...)
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                observer:onNext(true)
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Given a set of Observables, produces values from only the first one to produce a value.
    ---@param a Observable
    ---@param b Observable
    ---@param ... Observable
    ---@return Observable
    function Observable.amb(a, b, ...)
        if not a or not b then return a end

        return Observable.create(function(observer)
            local subscriptionA, subscriptionB

            local function onNextA(...)
                if subscriptionB then subscriptionB:unsubscribe() end
                observer:onNext(...)
            end

            local function onErrorA(e)
                if subscriptionB then subscriptionB:unsubscribe() end
                observer:onError(e)
            end

            local function onCompletedA()
                if subscriptionB then subscriptionB:unsubscribe() end
                observer:onCompleted()
            end

            local function onNextB(...)
                if subscriptionA then subscriptionA:unsubscribe() end
                observer:onNext(...)
            end

            local function onErrorB(e)
                if subscriptionA then subscriptionA:unsubscribe() end
                observer:onError(e)
            end

            local function onCompletedB()
                if subscriptionA then subscriptionA:unsubscribe() end
                observer:onCompleted()
            end

            subscriptionA = a:subscribe(onNextA, onErrorA, onCompletedA)
            subscriptionB = b:subscribe(onNextB, onErrorB, onCompletedB)

            return Subscription.create(function()
                subscriptionA:unsubscribe()
                subscriptionB:unsubscribe()
            end)
        end):amb(...)
    end

    --- Returns an Observable that produces the average of all values produced by the original.
    --- @return Observable
    function Observable:average()
        return Observable.create(function(observer)
            local sum, count = 0, 0

            local function onNext(value)
                sum = sum + value
                count = count + 1
            end

            local function onError(e)
                observer:onError(e)
            end

            local function onCompleted()
                if count > 0 then
                    observer:onNext(sum / count)
                end

                observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns an Observable that buffers values from the original and produces them as multiple
    -- values.
    --- @param size number - The size of the buffer.
    function Observable:buffer(size)
        if not size or type(size) ~= 'number' then
            error('Expected a number')
        end

        return Observable.create(function(observer)
            local buffer = {}

            local function emit()
                if #buffer > 0 then
                    observer:onNext(ReactiveXUtil.unpack(buffer))
                    buffer = {}
                end
            end

            local function onNext(...)
                local values = { ... }
                for i = 1, #values do
                    table.insert(buffer, values[i])
                    if #buffer >= size then
                        emit()
                    end
                end
            end

            local function onError(message)
                emit()
                return observer:onError(message)
            end

            local function onCompleted()
                emit()
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns an Observable that intercepts any errors from the previous and replace them with values
    -- produced by a new Observable.
    --- @param handler function|Observable - An Observable or a function that returns an Observable to replace the source Observable in the event of an error.
    --- @return Observable
    function Observable:catch(handler)
        handler = handler and (type(handler) == 'function' and handler or ReactiveXUtil.constant(handler))

        return Observable.create(function(observer)
            local subscription

            local function onNext(...)
                return observer:onNext(...)
            end

            local function onError(e)
                if not handler then
                    return observer:onCompleted()
                end

                local success, _continue = pcall(handler, e)
                if success and _continue then
                    if subscription then subscription:unsubscribe() end
                    _continue:subscribe(observer)
                else
                    observer:onError(success and e or _continue)
                end
            end

            local function onCompleted()
                observer:onCompleted()
            end

            subscription = self:subscribe(onNext, onError, onCompleted)
            return subscription
        end)
    end

    --- Returns a new Observable that runs a combinator function on the most recent values from a set
    -- of Observables whenever any of them produce a new value. The results of the combinator function
    -- are produced by the new Observable.
    --- @param ... Observable|function - One or more Observables to combine or a function that combines the latest result from each Observable and returns a single value.
    --- @return Observable
    function Observable:combineLatest(...)
        local sources = { ... }
        local combinator = table.remove(sources)
        if type(combinator) ~= 'function' then
            table.insert(sources, combinator)
            combinator = function(...) return ... end
        end
        table.insert(sources, 1, self)

        return Observable.create(function(observer)
            local latest = {}
            local pending = { ReactiveXUtil.unpack(sources) }
            local completed = {}
            local subscription = {}

            local function onNext(i)
                return function(value)
                    latest[i] = value
                    pending[i] = nil

                    if not next(pending) then
                        ReactiveXUtil.tryWithObserver(observer, function()
                            observer:onNext(combinator(ReactiveXUtil.unpack(latest)))
                        end)
                    end
                end
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted(i)
                return function()
                    table.insert(completed, i)

                    if #completed == #sources then
                        observer:onCompleted()
                    end
                end
            end

            for i = 1, #sources do
                subscription[i] = sources[i]:subscribe(onNext(i), onError, onCompleted(i))
            end

            return Subscription.create(function()
                for i = 1, #sources do
                    if subscription[i] then subscription[i]:unsubscribe() end
                end
            end)
        end)
    end

    --- Returns a new Observable that produces the values of the first with falsy values removed.
    --- @return Observable
    function Observable:compact()
        return self:filter(ReactiveXUtil.identity)
    end

    --- Returns a new Observable that produces the values produced by all the specified Observables in
    -- the order they are specified.
    --- @param other Observable - Observable to concatenate.
    --- @param ... Observable - The Observables to concatenate.
    --- @return Observable
    function Observable:concat(other, ...)
        if not other then return self end

        local others = { ... }

        return Observable.create(function(observer)
            local function onNext(...)
                return observer:onNext(...)
            end

            local function onError(message)
                return observer:onError(message)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            local function chain()
                return other:concat(ReactiveXUtil.unpack(others)):subscribe(onNext, onError, onCompleted)
            end

            return self:subscribe(onNext, onError, chain)
        end)
    end

    --- Returns a new Observable that produces a single boolean value representing whether or not the
    -- specified value was produced by the original.
    --- @param value any - The value to search for.  == is used for equality testing.
    --- @return Observable
    function Observable:contains(value)
        return Observable.create(function(observer)
            local subscription

            local function onNext(...)
                local args = ReactiveXUtil.pack(...)

                if #args == 0 and value == nil then
                    observer:onNext(true)
                    if subscription then subscription:unsubscribe() end
                    return observer:onCompleted()
                end

                for i = 1, #args do
                    if args[i] == value then
                        observer:onNext(true)
                        if subscription then subscription:unsubscribe() end
                        return observer:onCompleted()
                    end
                end
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                observer:onNext(false)
                return observer:onCompleted()
            end

            subscription = self:subscribe(onNext, onError, onCompleted)
            return subscription
        end)
    end

    --- Returns an Observable that produces a single value representing the number of values produced
    -- by the source value that satisfy an optional predicate.
    --- @param predicate function - The predicate used to match values.
    function Observable:count(predicate)
        predicate = predicate or ReactiveXUtil.constant(true)

        return Observable.create(function(observer)
            local count = 0

            local function onNext(...)
                ReactiveXUtil.tryWithObserver(observer, function(...)
                    if predicate(...) then
                        count = count + 1
                    end
                end, ...)
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                observer:onNext(count)
                observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns a new throttled Observable that waits to produce values until a timeout has expired, at
    -- which point it produces the latest value from the source Observable.  Whenever the source
    -- Observable produces a value, the timeout is reset.
    --- @param time number - An amount in milliseconds to wait before producing the last value.
    --- @param scheduler Scheduler - The scheduler to run the Observable on.
    --- @return Observable
    function Observable:debounce(time, scheduler)
        time = time or 0

        return Observable.create(function(observer)
            local debounced = {}

            local function wrap(key)
                return function(...)
                    local value = ReactiveXUtil.pack(...)

                    if debounced[key] then
                        debounced[key]:unsubscribe()
                    end

                    local values = ReactiveXUtil.pack(...)

                    debounced[key] = scheduler:schedule(function()
                        return observer[key](observer, ReactiveXUtil.unpack(values))
                    end, time)
                end
            end

            local subscription = self:subscribe(wrap('onNext'), wrap('onError'), wrap('onCompleted'))

            return Subscription.create(function()
                if subscription then subscription:unsubscribe() end
                for _, timeout in pairs(debounced) do
                    timeout:unsubscribe()
                end
            end)
        end)
    end

    --- Returns a new Observable that produces a default set of items if the source Observable produces
    -- no values.
    --- @param ... any - Zero or more values to produce if the source completes without emitting anything.
    --- @return Observable
    function Observable:defaultIfEmpty(...)
        local defaults = ReactiveXUtil.pack(...)

        return Observable.create(function(observer)
            local hasValue = false

            local function onNext(...)
                hasValue = true
                observer:onNext(...)
            end

            local function onError(e)
                observer:onError(e)
            end

            local function onCompleted()
                if not hasValue then
                    observer:onNext(ReactiveXUtil.unpack(defaults))
                end

                observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns a new Observable that produces the values of the original delayed by a time period.
    --- @param time number|function - An amount in milliseconds to delay by, or a function which returns this value.
    --- @param scheduler Scheduler - The scheduler to run the Observable on.
    --- @return Observable
    function Observable:delay(time, scheduler)
        time = type(time) ~= 'function' and ReactiveXUtil.constant(time) or time

        return Observable.create(function(observer)
            local actions = {}

            local function delay(key)
                return function(...)
                    local arg = ReactiveXUtil.pack(...)
                    local handle = scheduler:schedule(function()
                        observer[key](observer, ReactiveXUtil.unpack(arg))
                    end, time())
                    table.insert(actions, handle)
                end
            end

            local subscription = self:subscribe(delay('onNext'), delay('onError'), delay('onCompleted'))

            return Subscription.create(function()
                if subscription then subscription:unsubscribe() end
                for i = 1, #actions do
                    actions[i]:unsubscribe()
                end
            end)
        end)
    end

    --- Returns a new Observable that produces the values from the original with duplicates removed.
    --- @return Observable
    function Observable:distinct()
        return Observable.create(function(observer)
            local values = {}

            local function onNext(x)
                if not values[x] then
                    observer:onNext(x)
                end

                values[x] = true
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns an Observable that only produces values from the original if they are different from
    -- the previous value.
    --- @param comparator function - A function used to compare 2 values. If unspecified, == is used.
    --- @return Observable
    function Observable:distinctUntilChanged(comparator)
        comparator = comparator or ReactiveXUtil.eq

        return Observable.create(function(observer)
            local first = true
            local currentValue = nil

            local function onNext(value, ...)
                local values = ReactiveXUtil.pack(...)
                ReactiveXUtil.tryWithObserver(observer, function()
                    if first or not comparator(value, currentValue) then
                        observer:onNext(value, ReactiveXUtil.unpack(values))
                        currentValue = value
                        first = false
                    end
                end)
            end

            local function onError(message)
                return observer:onError(message)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns an Observable that produces the nth element produced by the source Observable.
    --- @param index number - The index of the item, with an index of 1 representing the first.
    --- @return Observable
    function Observable:elementAt(index)
        if not index or type(index) ~= 'number' then
            error('Expected a number')
        end

        return Observable.create(function(observer)
            local subscription
            local i = 1

            local function onNext(...)
                if i == index then
                    observer:onNext(...)
                    observer:onCompleted()
                    if subscription then
                        subscription:unsubscribe()
                    end
                else
                    i = i + 1
                end
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            subscription = self:subscribe(onNext, onError, onCompleted)
            return subscription
        end)
    end

    --- Returns a new Observable that only produces values of the first that satisfy a predicate.
    --- @param predicate function - The predicate used to filter values.
    --- @return Observable
    function Observable:filter(predicate)
        predicate = predicate or ReactiveXUtil.identity

        return Observable.create(function(observer)
            local function onNext(...)
                ReactiveXUtil.tryWithObserver(observer, function(...)
                    if predicate(...) then
                        return observer:onNext(...)
                    end
                end, ...)
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns a new Observable that produces the first value of the original that satisfies a
    -- predicate.
    --- @param predicate function - The predicate used to find a value.
    function Observable:find(predicate)
        predicate = predicate or ReactiveXUtil.identity

        return Observable.create(function(observer)
            local function onNext(...)
                ReactiveXUtil.tryWithObserver(observer, function(...)
                    if predicate(...) then
                        observer:onNext(...)
                        return observer:onCompleted()
                    end
                end, ...)
            end

            local function onError(message)
                return observer:onError(message)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns a new Observable that only produces the first result of the original.
    --- @return Observable
    function Observable:first()
        return self:take(1)
    end

    --- Returns a new Observable that transform the items emitted by an Observable into Observables,
    -- then flatten the emissions from those into a single Observable
    --- @param callback function - The function to transform values from the original Observable.
    --- @return Observable
    function Observable:flatMap(callback)
        callback = callback or ReactiveXUtil.identity
        return self:map(callback):flatten()
    end

    --- Returns a new Observable that uses a callback to create Observables from the values produced by
    -- the source, then produces values from the most recent of these Observables.
    --- @param callback function? - The function used to convert values to Observables. By default util.identity
    --- @return Observable
    function Observable:flatMapLatest(callback)
        callback = callback or ReactiveXUtil.identity
        return Observable.create(function(observer)
            local innerSubscription

            local function onNext(...)
                observer:onNext(...)
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            local function subscribeInner(...)
                if innerSubscription then
                    innerSubscription:unsubscribe()
                end

                return ReactiveXUtil.tryWithObserver(observer, function(...)
                    innerSubscription = callback(...):subscribe(onNext, onError)
                end, ...)
            end

            local subscription = self:subscribe(subscribeInner, onError, onCompleted)
            return Subscription.create(function()
                if innerSubscription then
                    innerSubscription:unsubscribe()
                end

                if subscription then
                    subscription:unsubscribe()
                end
            end)
        end)
    end

    --- Returns a new Observable that subscribes to the Observables produced by the original and
    -- produces their values.
    --- @return Observable
    function Observable:flatten()
        return Observable.create(function(observer)
            local subscriptions = {}
            local remaining = 1

            local function onError(message)
                return observer:onError(message)
            end

            local function onCompleted()
                remaining = remaining - 1
                if remaining == 0 then
                    return observer:onCompleted()
                end
            end

            local function onNext(observable)
                local function innerOnNext(...)
                    observer:onNext(...)
                end

                remaining = remaining + 1
                local subscription = observable:subscribe(innerOnNext, onError, onCompleted)
                subscriptions[#subscriptions + 1] = subscription
            end

            subscriptions[#subscriptions + 1] = self:subscribe(onNext, onError, onCompleted)
            return Subscription.create(function()
                for i = 1, #subscriptions do
                    subscriptions[i]:unsubscribe()
                end
            end)
        end)
    end

    --- Returns an Observable that terminates when the source terminates but does not produce any
    -- elements.
    --- @return Observable
    function Observable:ignoreElements()
        return Observable.create(function(observer)
            local function onError(message)
                return observer:onError(message)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            return self:subscribe(nil, onError, onCompleted)
        end)
    end

    --- Returns a new Observable that only produces the last result of the original.
    --- @return Observable
    function Observable:last()
        return Observable.create(function(observer)
            local value
            local empty = true

            local function onNext(...)
                value = { ... }
                empty = false
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                if not empty then
                    observer:onNext(ReactiveXUtil.unpack(value or {}))
                end

                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns a new Observable that produces the values of the original transformed by a function.
    --- @param callback function - The function to transform values from the original Observable.
    --- @return Observable
    function Observable:map(callback)
        return Observable.create(function(observer)
            callback = callback or ReactiveXUtil.identity

            local function onNext(...)
                return ReactiveXUtil.tryWithObserver(observer, function(...)
                    return observer:onNext(callback(...))
                end, ...)
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns a new Observable that produces the maximum value produced by the original.
    --- @return Observable
    function Observable:max()
        return self:reduce(math.max)
    end

    --- Returns a new Observable that produces the values produced by all the specified Observables in
    -- the order they are produced.
    --- @param ... Observable - One or more Observables to merge.
    --- @return Observable
    function Observable:merge(...)
        local sources = { ... }
        table.insert(sources, 1, self)

        return Observable.create(function(observer)
            local completed = {}
            local subscriptions = {}

            local function onNext(...)
                return observer:onNext(...)
            end

            local function onError(message)
                return observer:onError(message)
            end

            local function onCompleted(i)
                return function()
                    table.insert(completed, i)

                    if #completed == #sources then
                        observer:onCompleted()
                    end
                end
            end

            for i = 1, #sources do
                subscriptions[i] = sources[i]:subscribe(onNext, onError, onCompleted(i))
            end

            return Subscription.create(function()
                for i = 1, #sources do
                    if subscriptions[i] then subscriptions[i]:unsubscribe() end
                end
            end)
        end)
    end

    --- Returns a new Observable that produces the minimum value produced by the original.
    --- @return Observable
    function Observable:min()
        return self:reduce(math.min)
    end

    --- Returns an Observable that produces the values of the original inside tables.
    --- @return Observable
    function Observable:pack()
        return self:map(ReactiveXUtil.pack)
    end

    --- Returns two Observables: one that produces values for which the predicate returns truthy for,
    -- and another that produces values for which the predicate returns falsy.
    --- @param predicate function - The predicate used to partition the values.
    --- @return Observable, Observable
    function Observable:partition(predicate)
        return self:filter(predicate), self:reject(predicate)
    end

    --- Returns a new Observable that produces values computed by extracting the given keys from the
    -- tables produced by the original.
    --- @param ... string - The key to extract from the table. Multiple keys can be specified to recursively pluck values from nested tables.
    --- @return Observable
    function Observable:pluck(key, ...)
        if not key then return self end

        if type(key) ~= 'string' and type(key) ~= 'number' then
            return Observable.throw('pluck key must be a string')
        end

        return Observable.create(function(observer)
            local function onNext(t)
                return observer:onNext(t[key])
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end):pluck(...)
    end

    --- Returns a new Observable that produces a single value computed by accumulating the results of
    -- running a function on each value produced by the original Observable.
    --- @param accumulator function - Accumulates the values of the original Observable. Will be passed the return value of the last call as the first argument and the current values as the rest of the arguments.
    --- @param seed any - A value to pass to the accumulator the first time it is run.
    --- @return Observable
    function Observable:reduce(accumulator, seed)
        return Observable.create(function(observer)
            local result = seed
            local first = true

            local function onNext(...)
                if first and seed == nil then
                    result = ...
                    first = false
                else
                    return ReactiveXUtil.tryWithObserver(observer, function(...)
                        result = accumulator(result, ...)
                    end, ...)
                end
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                observer:onNext(result)
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns a new Observable that produces values from the original which do not satisfy a
    -- predicate.
    --- @param predicate function - The predicate used to reject values.
    --- @return Observable
    function Observable:reject(predicate)
        predicate = predicate or ReactiveXUtil.identity

        return Observable.create(function(observer)
            local function onNext(...)
                ReactiveXUtil.tryWithObserver(observer, function(...)
                    if not predicate(...) then
                        return observer:onNext(...)
                    end
                end, ...)
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns an Observable that restarts in the event of an error.
    --- @param count number - The maximum number of times to retry.  If left unspecified, an infinite number of retries will be attempted.
    --- @return Observable
    function Observable:retry(count)
        return Observable.create(function(observer)
            local subscription
            local retries = 0

            local function onNext(...)
                return observer:onNext(...)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            local function onError(message)
                if subscription then
                    subscription:unsubscribe()
                end

                retries = retries + 1
                if count and retries > count then
                    return observer:onError(message)
                end

                subscription = self:subscribe(onNext, onError, onCompleted)
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns a new Observable that produces its most recent value every time the specified observable
    -- produces a value.
    --- @param sampler Observable - The Observable that is used to sample values from this Observable.
    --- @return Observable
    function Observable:sample(sampler)
        if not sampler then error('Expected an Observable') end

        return Observable.create(function(observer)
            local latest = {}

            local function setLatest(...)
                latest = ReactiveXUtil.pack(...)
            end

            local function onNext()
                if #latest > 0 then
                    return observer:onNext(ReactiveXUtil.unpack(latest))
                end
            end

            local function onError(message)
                return observer:onError(message)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            local sourceSubscription = self:subscribe(setLatest, onError)
            local sampleSubscription = sampler:subscribe(onNext, onError, onCompleted)

            return Subscription.create(function()
                if sourceSubscription then sourceSubscription:unsubscribe() end
                if sampleSubscription then sampleSubscription:unsubscribe() end
            end)
        end)
    end

    --- Returns a new Observable that produces values computed by accumulating the results of running a
    -- function on each value produced by the original Observable.
    --- @param accumulator function - Accumulates the values of the original Observable. Will be passed the return value of the last call as the first argument and the current values as the rest of the arguments.  Each value returned from this function will be emitted by the Observable.
    --- @param seed any - A value to pass to the accumulator the first time it is run.
    --- @return Observable
    function Observable:scan(accumulator, seed)
        return Observable.create(function(observer)
            local result = seed
            local first = true

            local function onNext(...)
                if first and seed == nil then
                    result = ...
                    first = false
                else
                    return ReactiveXUtil.tryWithObserver(observer, function(...)
                        result = accumulator(result, ...)
                        observer:onNext(result)
                    end, ...)
                end
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns a new Observable that skips over a specified number of values produced by the original
    -- and produces the rest.
    --- @param n number - The number of values to ignore.
    --- @return Observable
    function Observable:skip(n)
        n = n or 1

        return Observable.create(function(observer)
            local i = 1

            local function onNext(...)
                if i > n then
                    observer:onNext(...)
                else
                    i = i + 1
                end
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns an Observable that omits a specified number of values from the end of the original
    -- Observable.
    --- @param count number - The number of items to omit from the end.
    --- @return Observable
    function Observable:skipLast(count)
        if not count or type(count) ~= 'number' then
            error('Expected a number')
        end

        local buffer = {}
        return Observable.create(function(observer)
            local function emit()
                if #buffer > count and buffer[1] then
                    local values = table.remove(buffer, 1)
                    observer:onNext(ReactiveXUtil.unpack(values))
                end
            end

            local function onNext(...)
                emit()
                table.insert(buffer, ReactiveXUtil.pack(...))
            end

            local function onError(message)
                return observer:onError(message)
            end

            local function onCompleted()
                emit()
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns a new Observable that skips over values produced by the original until the specified
    -- Observable produces a value.
    --- @param other Observable - The Observable that triggers the production of values.
    --- @return Observable
    function Observable:skipUntil(other)
        return Observable.create(function(observer)
            local triggered = false
            local function trigger()
                triggered = true
            end

            other:subscribe(trigger, trigger, trigger)

            local function onNext(...)
                if triggered then
                    observer:onNext(...)
                end
            end

            local function onError()
                if triggered then
                    ---@diagnostic disable-next-line: missing-parameter
                    observer:onError()
                end
            end

            local function onCompleted()
                if triggered then
                    observer:onCompleted()
                end
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns a new Observable that skips elements until the predicate returns falsy for one of them.
    --- @param predicate function - The predicate used to continue skipping values.
    --- @return Observable
    function Observable:skipWhile(predicate)
        predicate = predicate or ReactiveXUtil.identity

        return Observable.create(function(observer)
            local skipping = true

            local function onNext(...)
                if skipping then
                    ReactiveXUtil.tryWithObserver(observer, function(...)
                        skipping = predicate(...)
                    end, ...)
                end

                if not skipping then
                    return observer:onNext(...)
                end
            end

            local function onError(message)
                return observer:onError(message)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns a new Observable that produces the specified values followed by all elements produced by
    -- the source Observable.
    --- @param ... any - The values to produce before the Observable begins producing values normally.
    --- @return Observable
    function Observable:startWith(...)
        local values = ReactiveXUtil.pack(...)
        return Observable.create(function(observer)
            observer:onNext(ReactiveXUtil.unpack(values))
            return self:subscribe(observer)
        end)
    end

    --- Returns an Observable that produces a single value representing the sum of the values produced
    -- by the original.
    --- @return Observable
    function Observable:sum()
        return self:reduce(function(x, y) return x + y end, 0)
    end

    --- Given an Observable that produces Observables, returns an Observable that produces the values
    -- produced by the most recently produced Observable.
    --- @return Observable
    function Observable:switch()
        return Observable.create(function(observer)
            local innerSubscription

            local function onNext(...)
                return observer:onNext(...)
            end

            local function onError(message)
                return observer:onError(message)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            local function switch(source)
                if innerSubscription then
                    innerSubscription:unsubscribe()
                end

                innerSubscription = source:subscribe(onNext, onError, nil)
            end

            local subscription = self:subscribe(switch, onError, onCompleted)
            return Subscription.create(function()
                if innerSubscription then
                    innerSubscription:unsubscribe()
                end

                if subscription then
                    subscription:unsubscribe()
                end
            end)
        end)
    end

    --- Returns a new Observable that only produces the first n results of the original.
    --- @param n number - The number of elements to produce before completing.
    --- @return Observable
    function Observable:take(n)
        n = n or 1

        return Observable.create(function(observer)
            if n <= 0 then
                observer:onCompleted()
                return
            end

            local i = 1

            local function onNext(...)
                observer:onNext(...)

                i = i + 1

                if i > n then
                    observer:onCompleted()
                end
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns an Observable that produces a specified number of elements from the end of a source
    -- Observable.
    --- @param count number - The number of elements to produce.
    --- @return Observable
    function Observable:takeLast(count)
        if not count or type(count) ~= 'number' then
            error('Expected a number')
        end

        return Observable.create(function(observer)
            local buffer = {}

            local function onNext(...)
                table.insert(buffer, ReactiveXUtil.pack(...))
                if #buffer > count then
                    table.remove(buffer, 1)
                end
            end

            local function onError(message)
                return observer:onError(message)
            end

            local function onCompleted()
                for i = 1, #buffer do
                    observer:onNext(ReactiveXUtil.unpack(buffer[i]))
                end
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns a new Observable that completes when the specified Observable fires.
    --- @param other Observable - The Observable that triggers completion of the original.
    --- @return Observable
    function Observable:takeUntil(other)
        return Observable.create(function(observer)
            local function onNext(...)
                return observer:onNext(...)
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            other:subscribe(onCompleted, onCompleted, onCompleted)

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns a new Observable that produces elements until the predicate returns falsy.
    --- @param predicate function - The predicate used to continue production of values.
    --- @return Observable
    function Observable:takeWhile(predicate)
        predicate = predicate or ReactiveXUtil.identity

        return Observable.create(function(observer)
            local taking = true

            local function onNext(...)
                if taking then
                    ReactiveXUtil.tryWithObserver(observer, function(...)
                        taking = predicate(...)
                    end, ...)

                    if taking then
                        return observer:onNext(...)
                    else
                        return observer:onCompleted()
                    end
                end
            end

            local function onError(message)
                return observer:onError(message)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Runs a function each time this Observable has activity. Similar to subscribe but does not
    -- create a subscription.
    --- @param _onNext fun(...)? - Run when the Observable produces values.
    --- @param _onError fun(message:string)? - Run when the Observable encounters a problem.
    --- @param _onCompleted function? - Run when the Observable completes.
    --- @return Observable
    function Observable:tap(_onNext, _onError, _onCompleted)
        _onNext = _onNext or ReactiveXUtil.noop
        _onError = _onError or ReactiveXUtil.noop
        _onCompleted = _onCompleted or ReactiveXUtil.noop

        return Observable.create(function(observer)
            local function onNext(...)
                ReactiveXUtil.tryWithObserver(observer, function(...)
                    _onNext(...)
                end, ...)

                return observer:onNext(...)
            end

            local function onError(message)
                ReactiveXUtil.tryWithObserver(observer, function()
                    _onError(message)
                end)

                return observer:onError(message)
            end

            local function onCompleted()
                ReactiveXUtil.tryWithObserver(observer, function()
                    _onCompleted()
                end)

                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns an Observable that unpacks the tables produced by the original.
    --- @return Observable
    function Observable:unpack()
        return self:map(ReactiveXUtil.unpack)
    end

    --- Returns an Observable that takes any values produced by the original that consist of multiple
    -- return values and produces each value individually.
    --- @return Observable
    function Observable:unwrap()
        return Observable.create(function(observer)
            local function onNext(...)
                local values = { ... }
                for i = 1, #values do
                    observer:onNext(values[i])
                end
            end

            local function onError(message)
                return observer:onError(message)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns an Observable that produces a sliding window of the values produced by the original.
    --- @param size number - The size of the window. The returned observable will produce this number of the most recent values as multiple arguments to onNext.
    --- @return Observable
    function Observable:window(size)
        if not size or type(size) ~= 'number' then
            error('Expected a number')
        end

        return Observable.create(function(observer)
            local window = {}

            local function onNext(value)
                table.insert(window, value)

                if #window >= size then
                    observer:onNext(ReactiveXUtil.unpack(window))
                    table.remove(window, 1)
                end
            end

            local function onError(message)
                return observer:onError(message)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            return self:subscribe(onNext, onError, onCompleted)
        end)
    end

    --- Returns an Observable that produces values from the original along with the most recently
    -- produced value from all other specified Observables. Note that only the first argument from each
    -- source Observable is used.
    --- @param ... Observable - The Observables to include the most recent values from.
    --- @return Observable
    function Observable:with(...)
        local sources = { ... }

        return Observable.create(function(observer)
            local latest = setmetatable({}, { __len = ReactiveXUtil.constant(#sources) })
            local subscriptions = {}

            local function setLatest(i)
                return function(value)
                    latest[i] = value
                end
            end

            local function onNext(value)
                return observer:onNext(value, ReactiveXUtil.unpack(latest))
            end

            local function onError(e)
                return observer:onError(e)
            end

            local function onCompleted()
                return observer:onCompleted()
            end

            for i = 1, #sources do
                subscriptions[i] = sources[i]:subscribe(setLatest(i), ReactiveXUtil.noop, ReactiveXUtil.noop)
            end

            subscriptions[#sources + 1] = self:subscribe(onNext, onError, onCompleted)
            return Subscription.create(function()
                for i = 1, #sources + 1 do
                    if subscriptions[i] then subscriptions[i]:unsubscribe() end
                end
            end)
        end)
    end

    --- Returns an Observable that merges the values produced by the source Observables by grouping them
    -- by their index.  The first onNext event contains the first value of all of the sources, the
    -- second onNext event contains the second value of all of the sources, and so on.  onNext is called
    -- a number of times equal to the number of values produced by the Observable that produces the
    -- fewest number of values.
    --- @param ... Observable - The Observables to zip.
    --- @return Observable
    function Observable.zip(...)
        local sources = ReactiveXUtil.pack(...)
        local count = #sources

        return Observable.create(function(observer)
            local values = {}
            local active = {}
            local subscriptions = {}
            for i = 1, count do
                values[i] = { n = 0 }
                active[i] = true
            end

            local function onNext(i)
                return function(value)
                    table.insert(values[i], value)
                    values[i].n = values[i].n + 1

                    local ready = true
                    for i = 1, count do
                        if values[i].n == 0 then
                            ready = false
                            break
                        end
                    end

                    if ready then
                        local payload = {}

                        for i = 1, count do
                            payload[i] = table.remove(values[i], 1)
                            values[i].n = values[i].n - 1
                        end

                        observer:onNext(ReactiveXUtil.unpack(payload))
                    end
                end
            end

            local function onError(message)
                return observer:onError(message)
            end

            local function onCompleted(i)
                return function()
                    active[i] = nil
                    if not next(active) or values[i].n == 0 then
                        return observer:onCompleted()
                    end
                end
            end

            for i = 1, count do
                subscriptions[i] = sources[i]:subscribe(onNext(i), onError, onCompleted(i))
            end

            return Subscription.create(function()
                for i = 1, count do
                    if subscriptions[i] then subscriptions[i]:unsubscribe() end
                end
            end)
        end)
    end

    Observable.wrap = Observable.buffer
    Observable['repeat'] = Observable.replicate

    return Observable
end)
if Debug then Debug.endFile() end
