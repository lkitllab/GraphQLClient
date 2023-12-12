import Foundation
import Apollo
import Combine

enum NetworkError: Error {
    case noDataError, apolloClientError
}

public protocol UserTokenProvider {
    var authorizationToken: String? {get}
}

public protocol QueryWatcher {
    func watch<Query: GraphQLQuery>(
        _ query: Query,
        data: @escaping (Query.Data?) -> Void
    ) -> GraphQLQueryWatcher<Query>
}

public protocol CacheReader {
    func readFromCache<Operation: GraphQLOperation>(
        _ operation: Operation
    ) -> AnyPublisher<Operation.Data?, Error>
}

public protocol CacheWriter {
    func writeToChache<Operation: GraphQLQuery>(
        _ query: Operation,
        body: @escaping (inout Operation.Data) throws -> Void)
}

class Network: QueryWatcher {
    
    public var tokenProvider: UserTokenProvider?
    
    internal let imageCache = URLCache.shared
    internal let apollo: ApolloClient
    
    init(networkTransport: RequestChainNetworkTransport, store: ApolloStore) {
        apollo = ApolloClient(networkTransport: networkTransport, store: store)
    }
    
    public func fetch<Query: GraphQLQuery, T>(
        _ query: Query,
        cachePolicy: CachePolicy = .default,
        data: @escaping (Query.Data?)->T?)
    -> Future<T?, Error> {
        Future { [weak apollo] promise in
            guard let apollo = apollo else {
                promise(.failure(NetworkError.apolloClientError))
                return
            }
            apollo.fetch(query: query, cachePolicy: cachePolicy) { queryResult in
                switch queryResult {
                case .success(let graphQLResult):
                    guard let error = graphQLResult.errors?.first else {
                        promise(.success(data(graphQLResult.data)))
                        return
                    }
                    promise(.failure(error))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
    }
    
    public func perform<Mutation: GraphQLMutation, T>(
        _ mutation: Mutation,
        publishResultToStore: Bool = true,
        data: @escaping (Mutation.Data?)->T?)
    -> Future<T?, Error> {
        Future { [weak apollo] promise in
            guard let apollo = apollo else {
                promise(.failure(NetworkError.apolloClientError))
                return
            }
            apollo.perform(mutation: mutation, publishResultToStore: publishResultToStore) { queryResult in
                switch queryResult {
                case .success(let graphQLResult):
                    guard let error = graphQLResult.errors?.first else {
                        promise(.success(data(graphQLResult.data)))
                        return
                    }
                    promise(.failure(error))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
    }
    
    public func upload<Operation: GraphQLOperation, T>(
        operation: Operation,
        files: [GraphQLFile],
        data: @escaping (Operation.Data?)->T?
    ) -> Future<T?, Error> {
        Future { [weak apollo] promise in
            guard let apollo = apollo else {
                promise(.failure(NetworkError.apolloClientError))
                return
            }
            apollo.upload(operation: operation, files: files) { uploadResult in
                switch uploadResult {
                case .success(let graphQLResult):
                    guard let error = graphQLResult.errors?.first else {
                        promise(.success(data(graphQLResult.data)))
                        return
                    }
                    promise(.failure(error))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
    }
    
    public func subscribe<Subscription: GraphQLSubscription, T>(
        _ subscription: Subscription,
        data: @escaping (Subscription.Data?)->T?
    ) -> Future<T?, Error> {
        Future { [apollo] promise in
            apollo.subscribe(subscription: subscription) { result in
                switch result {
                case .success(let graphQLResult):
                    guard let error = graphQLResult.errors?.first else {
                        promise(.success(data(graphQLResult.data)))
                        return
                    }
                    promise(.failure(error))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
    }
    
    public func watch<Query: GraphQLQuery>(
        _ query: Query,
        data: @escaping (Query.Data?) -> Void
    ) -> GraphQLQueryWatcher<Query> {
        apollo.watch(query: query) { result in
            let resultData = try? result.get().data
            data(resultData)
        }
    }
}

extension Network: CacheReader, CacheWriter {
    
    public func readFromCache<Operation: GraphQLOperation>(
        _ operation: Operation
    ) -> AnyPublisher<Operation.Data?, Error> {
        Future { [apollo] promise in
            apollo.store.load(query: operation) { result in
                switch result {
                case .success(let graphQLResult):
                    guard let error = graphQLResult.errors?.first else {
                        promise(.success(graphQLResult.data))
                        return
                    }
                    promise(.failure(error))
                case .failure(let error):
                    promise(.failure(error))
                }
            }
        }
        .eraseToAnyPublisher()
    }
    
    public func writeToChache<Operation: GraphQLQuery>(
        _ query: Operation,
        body: @escaping (inout Operation.Data) throws -> Void) {
        apollo.store.withinReadWriteTransaction { transaction in
            try transaction.update(query: query, body)
        }
    }
    
    public func clearCache() -> AnyPublisher<Void, Error> {
        Future { [apollo] promise in
            apollo.store.clearCache { result in
                if case .failure(let error) = result {
                    promise(.failure(error))
                } else {
                    promise(.success(()))
                }
            }
        }
        .eraseToAnyPublisher()
    }
}

extension Network: UserTokenProvider {
    internal var authorizationToken: String? {
        tokenProvider?.authorizationToken
    }
}
