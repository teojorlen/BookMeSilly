#include "backend/Calculator.h"
#include <stdexcept>

namespace backend {

Calculator::Calculator() {
}

Calculator::~Calculator() {
}

// cppcheck-suppress unusedFunction
int Calculator::add(int a, int b) const {
    return a + b;
}

// cppcheck-suppress unusedFunction
int Calculator::subtract(int a, int b) const {
    return a - b;
}

// cppcheck-suppress unusedFunction
int Calculator::multiply(int a, int b) const {
    return a * b;
}

// cppcheck-suppress unusedFunction
int Calculator::divide(int a, int b) const {
    if (b == 0) {
        throw std::invalid_argument("Division by zero");
    }
    return a / b;
}

}  // namespace backend
