//
//  BlockProducerTask.swift
//  PSTask
//
//  Created by Ruslan Lutfullin on 1/12/20.
//

import Foundation

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public typealias BlockTask<Failure: Error> = BlockProducerTask<Void, Failure>

// MARK: -

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public typealias NonFailBlockTask = BlockTask<Never>

// MARK: -

@available(OSX 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
public final class BlockProducerTask<Output, Failure: Error>: ProducerTask<Output, Failure> {
  
  public typealias Block = (BlockProducerTask, @escaping (Produced) -> Void) -> Void
  
  private let block: Block
  
  // MARK: -
  
  public override func execute() { block(self) { (produced) in self.finish(with: produced) } }
  
  // MARK: -
  
  public init(
    name: String? = nil,
    qos: QualityOfService = .default,
    priority: Operation.QueuePriority = .normal,
    block: @escaping Block
  ) {
    self.block = block
    super.init(name: name, qos: qos, priority: priority)
  }
}
