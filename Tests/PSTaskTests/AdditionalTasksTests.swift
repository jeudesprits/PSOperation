//
//  AdditionalTasksTests.swift
//  PSTaskTests
//
//  Created by Ruslan Lutfullin on 2/4/20.
//

import XCTest
@testable import PSTask

final class AdditionalTasksTests: XCTestCase {
  
  private let queue = TaskQueue(name: "com.pstask.additional-tasks-tests", qos: .userInitiated)
  
  // MARK: -
  
  func testBlockProducerTask() {
    let expec = XCTestExpectation()
    
    let task =
      BlockProducerTask<Int, String>(
        name: "BlockProducerTask",
        qos: .userInitiated, priority: .veryHigh
      ) { (task, finish) in
        Thread.sleep(forTimeInterval: 1.0)
        finish(.success(21))
      }.recieve {
        switch $0 {
        case let .success(value):
          XCTAssertEqual(value, 21)
        case .failure:
          XCTFail()
        }
        
        expec.fulfill()
      }
    
    self.queue.addTask(task)
    
    self.wait(for: [expec], timeout: 2)
  }
  
  func testBlockTask() {
    let expec = XCTestExpectation()
    
    let task =
      BlockTask<String>(
        name: "BlockProducerTask",
        qos: .userInitiated, priority: .veryHigh
      ) { (task, finish) in
        Thread.sleep(forTimeInterval: 1.0)
        finish(.failure(.provided("Oops")))
      }.recieve {
        switch $0 {
        case .success, .failure(.internal):
          XCTFail()
        case let .failure(.provided(error)):
          XCTAssertEqual(error, "Oops")
        }
        
        expec.fulfill()
    }
    
    self.queue.addTask(task)
    
    self.wait(for: [expec], timeout: 2)
  }
  
  func testNonFailBlockTask() {
    let expec = XCTestExpectation()
    
    let task =
      NonFailBlockTask(
        name: "BlockProducerTask",
        qos: .userInitiated, priority: .veryHigh
      ) { (task, finish) in
        Thread.sleep(forTimeInterval: 1.0)
        finish(.success)
      }.recieve {
        switch $0 {
        case .success:
          XCTAssertTrue(true)
        case .failure:
          XCTFail()
        }
        
        expec.fulfill()
      }
    
    self.queue.addTask(task)
    
    self.wait(for: [expec], timeout: 2)
  }
  
  func testNonFailBlockProducerTask() {
    let expec = XCTestExpectation()
    
    let task =
      NonFailBlockProducerTask<Int>(
        qos: .userInitiated,
        priority: .veryHigh
      ) { (task, finish) in
        Thread.sleep(forTimeInterval: 1.0)
        finish(.success(21))
      }.recieve {
        switch $0 {
        case let .success(value):
          XCTAssertEqual(value, 21)
        case .failure:
          XCTFail()
        }
        
        expec.fulfill()
    }
    
    self.queue.addTask(task)
    
    self.wait(for: [expec], timeout: 2)
  }
  
  // MARK: -
  
  func testBlockConsumerProducerTask() {
    let expec = XCTestExpectation()
    
    let producerTask =
      BlockProducerTask<Int, String>(
        qos: .userInitiated,
        priority: .veryHigh
      ) { (task, finish) in
        Thread.sleep(forTimeInterval: 1.0)
        finish(.success(21))
    }
    
    let consumerTask =
      BlockConsumerProducerTask<Int, Int, String>(
        qos: .userInitiated,
        priority: .veryHigh,
        producing: producerTask
      ) { (task, consumed, finish) in
        Thread.sleep(forTimeInterval: 1.0)
        
        switch consumed {
        case let .success(value):
          XCTAssertEqual(value, 21)
          finish(.success(value + 21))
        case .failure:
          XCTFail()
        }
      }.recieve {
        switch $0 {
        case let .success(value):
          XCTAssertEqual(value, 42)
          expec.fulfill()
        case .failure:
          XCTFail()
        }
      }
    
    self.queue.addTask(producerTask)
    self.queue.addTask(consumerTask)
    
    self.wait(for: [expec], timeout: 3)
  }
  
  func testBlockConsumerTask() {
    let expec = XCTestExpectation()
    
    let producerTask =
      BlockProducerTask<Int, String>(
        qos: .userInitiated,
        priority: .veryHigh
      ) { (task, finish) in
        Thread.sleep(forTimeInterval: 1.0)
        finish(.success(21))
    }
    
    let consumerTask =
      BlockConsumerTask<Int, String>(
        qos: .userInitiated,
        priority: .veryHigh,
        producing: producerTask
      ) { (task, consumed, finish) in
        Thread.sleep(forTimeInterval: 1.0)
        
        switch consumed {
        case let .success(value):
          XCTAssertEqual(value, 21)
          finish(.success)
        case .failure:
          XCTFail()
        }
      }.recieve {
        switch $0 {
        case .success:
          XCTAssertTrue(true)
          expec.fulfill()
        case .failure:
          XCTFail()
        }
    }
    
    self.queue.addTask(producerTask)
    self.queue.addTask(consumerTask)
    
    self.wait(for: [expec], timeout: 3)
  }
  
  func testNonFailBlockConsumerTask() {
    let expec = XCTestExpectation()
    
    let producerTask =
      NonFailBlockProducerTask<Int>(
        qos: .userInitiated,
        priority: .veryHigh
      ) { (task, finish) in
        Thread.sleep(forTimeInterval: 1.0)
        finish(.success(21))
      }
    
    let consumerTask =
      NonFailBlockConsumerTask<Int>(
        qos: .userInitiated,
        priority: .veryHigh,
        producing: producerTask
      ) { (task, consumed, finish) in
        Thread.sleep(forTimeInterval: 1.0)
        
        switch consumed {
        case let .success(value):
          XCTAssertEqual(value, 21)
          finish(.success)
        case .failure:
          XCTFail()
        }
      }.recieve {
        switch $0 {
        case .success:
          XCTAssertTrue(true)
          expec.fulfill()
        case .failure:
          XCTFail()
        }
    }
    
    self.queue.addTask(producerTask)
    self.queue.addTask(consumerTask)
    
    self.wait(for: [expec], timeout: 3)
  }
  
  func testNonFailBlockConsumerProducerTask() {
    let expec = XCTestExpectation()
    
    let producerTask =
      NonFailBlockProducerTask<Int>(
        qos: .userInitiated,
        priority: .veryHigh
      ) { (task, finish) in
        Thread.sleep(forTimeInterval: 1.0)
        finish(.success(21))
    }
    
    let consumerTask =
      NonFailBlockConsumerProducerTask<Int, Int>(
        qos: .userInitiated,
        priority: .veryHigh,
        producing: producerTask
      ) { (task, consumed, finish) in
        Thread.sleep(forTimeInterval: 1.0)
        
        switch consumed {
        case let .success(value):
          XCTAssertEqual(value, 21)
          finish(.success(value + 21))
        case .failure:
          XCTFail()
        }
      }.recieve {
        switch $0 {
        case let .success(value):
          XCTAssertEqual(value, 42)
          expec.fulfill()
        case .failure:
          XCTFail()
        }
    }
    
    self.queue.addTask(producerTask)
    self.queue.addTask(consumerTask)
    
    self.wait(for: [expec], timeout: 3)
  }
  
  // MARK: -
  
  func testEmptyTask() {
    let expec = XCTestExpectation()
    
    let task =
      EmptyTask(qos: .userInitiated, priority: .veryHigh)
        .recieve {
          switch $0 {
          case .success:
            XCTAssertTrue(true)
            expec.fulfill()
          case .failure:
            XCTFail()
          }
        }
    
    self.queue.addTask(task)
    
    self.wait(for: [expec], timeout: 1)
  }
  
  // MARK: -
  
  func testGatedTask() {
    let expec = XCTestExpectation()
    
    final class MyOperation: Operation { override func main() { Thread.sleep(forTimeInterval: 2) } }
    
    let myop = MyOperation()
    
    let task =
      GatedTask(
        qos: .userInitiated,
        priority: .veryHigh,
        operation: myop
      ).recieve {
        switch $0 {
        case .success:
          XCTAssertTrue(true)
          expec.fulfill()
        case .failure:
          XCTFail()
        }
      }
    
    self.queue.addTask(task)

    self.wait(for: [expec], timeout: 3)
  }
  
  // MARK: -
  
  static var allTests = [
    ("testBlockProducerTask", testBlockProducerTask),
    ("testBlockTask", testBlockTask),
    ("testNonFailBlockTask", testNonFailBlockTask),
    ("testNonFailBlockProducerTask", testNonFailBlockProducerTask),
    ("testBlockConsumerProducerTask", testBlockConsumerProducerTask),
    ("testBlockConsumerTask", testBlockConsumerTask),
    ("testNonFailBlockConsumerTask", testNonFailBlockConsumerTask),
    ("testNonFailBlockConsumerProducerTask", testNonFailBlockConsumerProducerTask),
    ("testEmptyTask", testEmptyTask),
    ("testGatedTask", testGatedTask),
  ]
}
