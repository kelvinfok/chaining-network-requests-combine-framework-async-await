//
//  ContentView.swift
//  combine-network-requests
//
//  Created by Kelvin Fok on 10/10/21.
//

import SwiftUI
import Combine

struct ContentView: View {
  @ObservedObject var viewModel = ViewModel()
  var body: some View {
    List(viewModel.comments) { comment in
      Text(comment.email)
    }
    .onAppear {
      viewModel.fetchComments_withAwaitAsync()
    }
  }
}

struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}

class ViewModel: ObservableObject {
  
  @Published var comments: [Comment] = []
  
  private let combineService = CombineImp()
  private let awaitAsyncService = AwaitAsyncImp()
  private var subscribers = Set<AnyCancellable>()
  
  func fetchComments_withCombine() {
    // fetch users -> pick the last one
    // fetch all the posts from the user -> pick the last post
    // fetch all the comments from the last post
    combineService.getUsers().flatMap { [weak self] users -> AnyPublisher<[Post], Error> in
      if let user = users.last, let this = self {
        return this.combineService.getPosts(userId: user.id)
      } else {
        return Fail(error: APIError.emptyUsers).eraseToAnyPublisher()
      }
    }.flatMap { [weak self] posts -> AnyPublisher<[Comment], Error> in
      if let post = posts.last, let this = self {
        return this.combineService.getComments(postId: post.id)
      } else {
        return Fail(error: APIError.emptyPosts).eraseToAnyPublisher()
      }
    }.sink { result in
      switch result {
      case .failure(let error):
        print(error.localizedDescription)
      default:
        print("completed!")
      }
    } receiveValue: { comments in
      DispatchQueue.main.async {
        self.comments = comments
      }
    }.store(in: &subscribers)
  }
  
  func fetchComments_withAwaitAsync() {
    
    Task(priority: .background) {
      // fetch users -> pick the last one
      // fetch all the posts from the user -> pick the last post
      // fetch all the comments from the last post
      let usersResult: Result<[User], Error> = await awaitAsyncService.getUsers()
      guard case .success(let users) = usersResult, let user = users.first else { return }
      let postsResults = await awaitAsyncService.getPosts(userId: user.id)
      guard case .success(let posts) = postsResults, let post = posts.first else { return }
      let commentsResults = await awaitAsyncService.getComments(postId: post.id)
      guard case .success(let comments) = commentsResults else { return }
      DispatchQueue.main.async {
        self.comments = comments
      }
    }
  }
}

struct User: Decodable {
  let id: Int
  let name: String
}

struct Post: Decodable {
  let id: Int
  let userId: Int
  let title: String
}

struct Comment: Decodable, Identifiable {
  let id: Int
  let postId: Int
  let email: String
}


enum APIError: Error {
  case emptyUsers
  case emptyPosts
  case emptyComments
}

struct CombineImp {
  
  func getUsers() -> AnyPublisher<[User], Error> {
    let url = URL(string: "https://jsonplaceholder.typicode.com/users")!
    return URLSession.shared.dataTaskPublisher(for: url)
      .map({ $0.data })
      .decode(type: [User].self, decoder: JSONDecoder())
      .eraseToAnyPublisher()
  }
  
  func getPosts(userId: Int) -> AnyPublisher<[Post], Error> {
    let url = URL(string: "https://jsonplaceholder.typicode.com/posts?userId=\(userId)")!
    return URLSession.shared.dataTaskPublisher(for: url)
      .map({ $0.data })
      .decode(type: [Post].self, decoder: JSONDecoder())
      .eraseToAnyPublisher()
  }
  
  func getComments(postId: Int) -> AnyPublisher<[Comment], Error> {
    let url = URL(string: "https://jsonplaceholder.typicode.com/comments?postId=\(postId)")!
    return URLSession.shared.dataTaskPublisher(for: url)
      .map({ $0.data })
      .decode(type: [Comment].self, decoder: JSONDecoder())
      .eraseToAnyPublisher()
  }
}

struct AwaitAsyncImp {
  
  func getUsers() async -> Result<[User], Error> {
    do {
      let url = URL(string: "https://jsonplaceholder.typicode.com/users")!
      let (data, _) = try await URLSession.shared.data(from: url)
      let users = try JSONDecoder().decode([User].self, from: data)
      return .success(users)
    } catch(let error) {
      return .failure(error)
    }
  }
  
  func getPosts(userId: Int) async -> Result<[Post], Error> {
    do {
      let url = URL(string: "https://jsonplaceholder.typicode.com/posts?userId=\(userId)")!
      let (data, _) = try await URLSession.shared.data(from: url)
      let posts = try JSONDecoder().decode([Post].self, from: data)
      return .success(posts)
    } catch(let error) {
      return .failure(error)
    }
  }
  
  func getComments(postId: Int) async -> Result<[Comment], Error> {
    do {
      let url = URL(string: "https://jsonplaceholder.typicode.com/comments?postId=\(postId)")!
      let (data, _) = try await URLSession.shared.data(from: url)
      let comments = try JSONDecoder().decode([Comment].self, from: data)
      return .success(comments)
    } catch(let error) {
      return .failure(error)
    }
  }
}
