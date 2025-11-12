/*
 * Copyright (c) Huawei Technologies Co., Ltd. 2025. All rights reserved.
 * This source file is part of the Cangjie project, licensed under Apache-2.0.
 *
 * This is a modification of a file originally part of the stdx Cangjie library
 * under the same license.
 *
 * See https://cangjie-lang.cn/pages/LICENSE for license information.
 */

package effects.internal

public class DoubleResumeException <: Exception {
    public init() {
        super("Resumption resumed multiple times")
    }
    protected override func getClassName(): String {
        "DoubleResumeException"
    }
}

public class UnhandledCommandException <: Exception {
    public init() {
        super("Unhandled command")
    }
    protected override func getClassName(): String {
        "UnhandledCommand"
    }
}

public abstract class Command<Res> {
    public open func defaultImpl(): Res {
        throw UnhandledCommandException()
    }
}
