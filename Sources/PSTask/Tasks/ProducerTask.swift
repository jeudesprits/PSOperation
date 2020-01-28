//
//  ProducerOperation.swift
//  PSOperation
//
//  Created by Ruslan Lutfullin on 1/4/20.
//

import Foundation
import PSLock

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public enum ProducerTaskError: Error { case conditionsFailure, executionFailure }

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *) // TODO: - Добавить `removeDependecies`
open class ProducerTask<Output, Failure: Error>: Operation, ProducerTaskProtocol {
  
  public typealias Output = Output
  public typealias Failure = Failure
  
  // MARK: -
  
  private static var keyPathsForValuesAffectings: Set<String> { ["state"] }
  
  @objc
  private static func keyPathsForValuesAffectingIsReady() -> Set<String> { keyPathsForValuesAffectings }
  
  @objc
  private static func keyPathsForValuesAffectingIsExecuting() -> Set<String> { keyPathsForValuesAffectings }
  
  @objc
  private static func keyPathsForValuesAffectingIsFinished() -> Set<String> { keyPathsForValuesAffectings }
  
  // MARK: -
  
  private let stateLock = PSUnfairLock()
  private var _state = _State.initialized
  private var state: _State {
    get { stateLock.sync { _state } }
    set(newState) {
      // It's important to note that the KVO notifications are NOT called from inside
      // the lock. If they were, the app would deadlock, because in the middle of
      // calling the `didChangeValueForKey()` method, the observers try to access
      // properties like `isReady` or `isFinished`. Since those methods also
      // acquire the lock, then we'd be stuck waiting on our own lock. It's the
      // classic definition of deadlock.
      willChangeValue(forKey: "state")
      stateLock.sync {
        guard _state != .finished else { return }
        precondition(_state.canTransition(to: newState), "Performing invalid state transition.")
        _state = newState
      }
      didChangeValue(forKey: "state")
    }
  }
  
  // MARK: -
  
  open private(set) var produced: Produced?
  
  // MARK: -
  
  open private(set) var conditions = [AnyTaskCondition]()
  
  @discardableResult
  open func addCondition<C: TaskCondition>(_ condition: C) -> Self {
    precondition(state < .pending, "Cannot modify conditions after execution has begun.")
    conditions.append(.init(condition))
    return self
  }
  
  private func evaluateConditions() {
    precondition(state == .pending, "\(#function) was called out-of-order.")

    state = .evaluatingConditions

    _ConditionEvaluator.evaluate(conditions, for: self) { (results) in
      let errors = results
        .compactMap { (result) -> Swift.Error? in
          if case let .failure(error) = result {
            return error
          } else {
            return nil
          }
        }

      if !errors.isEmpty { self.produced = .failure(.internalFailure(ProducerTaskError.conditionsFailure)) }

      self.state = .ready
    }
  }
  
  // MARK: -
  
  open private(set) var observers = [Observer]()
  
  @discardableResult
  open func addObserver<O: Observer>(_ observer: O) -> Self {
    precondition(state < .executing, "Cannot modify observers after execution has begun.")
    observers.append(observer)
    return self
  }
  
  // MARK: -
  
  open override var isReady: Bool {
    switch state {
    case .initialized:
      if isCancelled { state = .pending }
      return false
    case .pending:
      evaluateConditions()
      // Until conditions have been evaluated, `isReady` returns false
      return false
    case .ready:
      return super.isReady || isCancelled
    default:
      return false
    }
  }
  
  open override var isExecuting: Bool { state == .executing }
  
  open override var isFinished: Bool { state == .finished }
  
  // MARK: -
  
  open func willEnqueue() {
    precondition(state != .ready, "You should not call the `cancel()` method before adding to the queue.")
    state = .pending
  }
  
  open override func start() {
    // `Operation.start()` method contains important logic that shouldn't be bypassed.
    super.start()
    // If the operation has been cancelled, we still need to enter the `.finished` state.
    if isCancelled { finish(with: produced ?? .failure(.internalFailure(ProducerTaskError.executionFailure))) }
  }
  
  open override func cancel() {
    super.cancel()
    observers.forEach { $0.taskDidCancel(self) }
  }
  
  open override func main() {
    precondition(state == .ready, "This operation must be performed on an operation queue.")
    
    if produced == nil && !isCancelled {
      state = .executing
      observers.forEach { $0.taskDidStart(self) }
      execute()
    } else {
      finish(with: produced ?? .failure(.internalFailure(ProducerTaskError.conditionsFailure)))
    }
  }
  
  // MARK: -

  open func execute() {
   // _abstract()
    
  }
  
  // MARK: -
  
  open func produce<T: ProducerTaskProtocol>(new task: T) { observers.forEach { $0.task(self, didProduce: task) } }
  
  // MARK: -
  
  private var hasFinishedAlready = false
  
  open func finish(with produced: Produced) {
    if !hasFinishedAlready {
      self.produced = produced
      hasFinishedAlready = true
      state = .finishing
      producedCompletionBlock?(produced)
      finished(with: produced)
      observers.forEach { $0.taskDidFinish(self) }
      state = .finished
    }
  }
  
  open func finished(with produced: Produced) {}
  
  public final override func waitUntilFinished() {
    // Waiting on operations is almost NEVER the right thing to do. It is
    // usually superior to use proper locking constructs, such as `dispatch_semaphore_t`
    // or `dispatch_group_notify`, or even `NSLocking` objects. Many developers
    // use waiting when they should instead be chaining discrete operations
    // together using dependencies.
    //
    // To reinforce this idea, invoking `waitUntilFinished()` method will crash your
    // app, as incentive for you to find a more appropriate way to express
    // the behavior you're wishing to create.
    #if !DEBUG
    fatalError(
      """
      Waiting on operations is an anti-pattern. Remove this ONLY if you're absolutely \
      sure there is No Other Way™.
      """
    )
    #else
    super.waitUntilFinished()
    #endif
  }
  
  // MARK: -
  
  @available(*, unavailable)
  open override func addDependency(_ operation: Operation) {}
  
  @discardableResult
  open func addDependency<T: ProducerTaskProtocol>(_ task: T) -> Self {
    precondition(state < .executing, "Dependencies cannot be modified after execution has begun.")
    super.addDependency(task)
    return self
  }
  
  @discardableResult
  open func addDependencies<T: ProducerTaskProtocol>(_ tasks: [T]) -> Self {
    tasks.forEach { addDependency($0) }
    return self
  }
  
  // MARK: -
  
  @available(*, unavailable)
  open override var completionBlock: (() -> Void)? { didSet {} }
  
  private var producedCompletionBlock: ((Produced) -> Void)?
  
  open func recieve(completion: @escaping (Produced) -> Void) { producedCompletionBlock = completion }
  
  // MARK: -
  
  @available(*, unavailable)
  public override init() {}
  
  public init(
    name: String? = nil,
    qos: QualityOfService = .default,
    priority: Operation.QueuePriority = .normal
  ) {
    super.init()
    self.name = name ?? String(describing: Self.self)
    qualityOfService = qos
    queuePriority = priority
  }
}

extension ProducerTask {
  
  internal enum _State: Int {
    
    case initialized
    case pending
    case evaluatingConditions
    case ready
    case executing
    case finishing
    case finished
  }
}

extension ProducerTask._State {
  
  internal func canTransition(to newState: Self) -> Bool {
    switch (self, newState) {
    case (.initialized, .pending),
         (.pending, .evaluatingConditions),
         (.evaluatingConditions, .ready),
         (.ready, .executing),
         (.ready, .finishing),
         (.executing, .finishing),
         (.finishing, .finished):
      return true
    default:
      return false
    }
  }
}

extension ProducerTask._State: Comparable {
  
  internal static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
  
  internal static func == (lhs: Self, rhs: Self) -> Bool { lhs.rawValue == rhs.rawValue }
}