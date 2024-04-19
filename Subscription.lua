if Debug then Debug.beginFile "ReactiveX/Subscription" end
OnInit.module("ReactiveX/Subscription", function(require)
    require "ReactiveX/Util"

    --- @class Subscription
    --- @field action function
    --- @field unsubscribed boolean
    -- A handle representing the link between an Observer and an Observable, as well as any
    -- work required to clean up after the Observable completes or the Observer unsubscribes.
    Subscription = {}
    Subscription.__index = Subscription
    Subscription.__tostring = ReactiveXUtil.constant('Subscription')

    -- Creates a new Subscription.
    ---@param action? fun(subscription: Subscription) action - The action to run when the subscription is unsubscribed. It will only be run once.
    ---@return Subscription
    function Subscription.create(action)
        return setmetatable({
            action = action or ReactiveXUtil.noop,
            unsubscribed = false
        }, Subscription)
    end

    --- Unsubscribes the subscription, performing any necessary cleanup work.
    function Subscription:unsubscribe()
        if self.unsubscribed then return end
        self.action(self)
        self.unsubscribed = true
    end

    return Subscription
end)
if Debug then Debug.endFile() end