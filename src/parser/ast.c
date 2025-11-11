
#include "../../include/parser/ast.h"

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

// ===== Memory Management =====

void ast_free_expr(Expr* expr) {
    if(!expr)
        return;

    switch(expr->type) {
        case EXPR_LITERAL:
            if(expr->as.literal.type == LITERAL_STRING) {
                free(expr->as.literal.value.string_val);
            }
            break;

        case EXPR_VARIABLE:
            free(expr->as.variable.name);
            break;

        case EXPR_BINARY:
            ast_free_expr(expr->as.binary.left);
            ast_free_expr(expr->as.binary.right);
            break;

        case EXPR_UNARY:
            ast_free_expr(expr->as.unary.right);
            break;

        case EXPR_CALL:
            ast_free_expr(expr->as.call.callee);
            for(size_t i = 0; i < expr->as.call.arg_count; i++) {
                ast_free_expr(expr->as.call.args[i]);
            }
            free(expr->as.call.args);
            break;

        case EXPR_INDEX:
            ast_free_expr(expr->as.index.object);
            ast_free_expr(expr->as.index.index);
            break;

        case EXPR_ARRAY:
            for(size_t i = 0; i < expr->as.array.count; i++) {
                ast_free_expr(expr->as.array.elements[i]);
            }
            free(expr->as.array.elements);
            break;

        case EXPR_ASSIGN:
            free(expr->as.assign.name);
            ast_free_expr(expr->as.assign.value);
            break;
    }

    free(expr);
}

void ast_free_stmt(Stmt* stmt) {
    if(!stmt)
        return;

    switch(stmt->type) {
        case STMT_EXPR:
            ast_free_expr(stmt->as.expr_stmt.expression);
            break;

        case STMT_VAR_DECL:
            free(stmt->as.var_decl.name);
            if(stmt->as.var_decl.type_annotation) {
                free(stmt->as.var_decl.type_annotation);
            }
            if(stmt->as.var_decl.initializer) {
                ast_free_expr(stmt->as.var_decl.initializer);
            }
            break;

        case STMT_FUNCTION_DECL:
            free(stmt->as.function_decl.name);
            for(size_t i = 0; i < stmt->as.function_decl.param_count; i++) {
                free(stmt->as.function_decl.param_names[i]);
                free(stmt->as.function_decl.param_types[i]);
            }
            free(stmt->as.function_decl.param_names);
            free(stmt->as.function_decl.param_types);
            if(stmt->as.function_decl.return_type) {
                free(stmt->as.function_decl.return_type);
            }
            ast_free_stmt(stmt->as.function_decl.body);
            break;

        case STMT_IF:
            ast_free_expr(stmt->as.if_stmt.condition);
            ast_free_stmt(stmt->as.if_stmt.then_branch);
            if(stmt->as.if_stmt.else_branch) {
                ast_free_stmt(stmt->as.if_stmt.else_branch);
            }
            break;

        case STMT_WHILE:
            ast_free_expr(stmt->as.while_stmt.condition);
            ast_free_stmt(stmt->as.while_stmt.body);
            break;

        case STMT_RETURN:
            if(stmt->as.return_stmt.value) {
                ast_free_expr(stmt->as.return_stmt.value);
            }
            break;

        case STMT_BLOCK:
            for(size_t i = 0; i < stmt->as.block.count; i++) {
                ast_free_stmt(stmt->as.block.statements[i]);
            }
            free(stmt->as.block.statements);
            break;
    }

    free(stmt);
}

void ast_free_node(ASTNode* node) {
    if(!node)
        return;

    if(node->type == NODE_PROGRAM) {
        for(size_t i = 0; i < node->as.program.count; i++) {
            ast_free_stmt(node->as.program.statements[i]);
        }
        free(node->as.program.statements);
    }

    free(node);
}

// ===== Printing (for debugging) =====

static void print_indent(int indent) {
    for(int i = 0; i < indent; i++) {
        printf("  ");
    }
}

static const char* token_type_to_string(TokenType type) {
    switch(type) {
        case TOKEN_PLUS:
            return "+";
        case TOKEN_MINUS:
            return "-";
        case TOKEN_ASTERISK:
            return "*";
        case TOKEN_SLASH:
            return "/";
        case TOKEN_BANG:
            return "!";
        case TOKEN_EQUAL:
            return "==";
        case TOKEN_NOT_EQUAL:
            return "!=";
        case TOKEN_LESS_THAN:
            return "<";
        case TOKEN_GREATER_THAN:
            return ">";
        case TOKEN_AND:
            return "and";
        case TOKEN_OR:
            return "or";
        case TOKEN_OR_ELSE:
            return "orelse";
        case TOKEN_ASSIGN:
            return "=";
        default:
            return "?";
    }
}

void ast_print_expr(Expr* expr, int indent) {
    if(!expr) {
        print_indent(indent);
        printf("<null>\n");
        return;
    }

    print_indent(indent);

    switch(expr->type) {
        case EXPR_LITERAL:
            printf("Literal(");
            switch(expr->as.literal.type) {
                case LITERAL_INT:
                    printf("%d", expr->as.literal.value.int_val);
                    break;
                case LITERAL_FLOAT:
                    printf("%f", expr->as.literal.value.float_val);
                    break;
                case LITERAL_STRING:
                    printf("\"%s\"", expr->as.literal.value.string_val);
                    break;
                case LITERAL_BOOL:
                    printf("%s", expr->as.literal.value.bool_val ? "true" : "false");
                    break;
            }
            printf(")\n");
            break;

        case EXPR_VARIABLE:
            printf("Variable(%s)\n", expr->as.variable.name);
            break;

        case EXPR_BINARY:
            printf("Binary(%s)\n", token_type_to_string(expr->as.binary.op));
            ast_print_expr(expr->as.binary.left, indent + 1);
            ast_print_expr(expr->as.binary.right, indent + 1);
            break;

        case EXPR_UNARY:
            printf("Unary(%s)\n", token_type_to_string(expr->as.unary.op));
            ast_print_expr(expr->as.unary.right, indent + 1);
            break;

        case EXPR_CALL:
            printf("Call\n");
            print_indent(indent + 1);
            printf("Callee:\n");
            ast_print_expr(expr->as.call.callee, indent + 2);
            print_indent(indent + 1);
            printf("Args(%zu):\n", expr->as.call.arg_count);
            for(size_t i = 0; i < expr->as.call.arg_count; i++) {
                ast_print_expr(expr->as.call.args[i], indent + 2);
            }
            break;

        case EXPR_INDEX:
            printf("Index\n");
            print_indent(indent + 1);
            printf("Object:\n");
            ast_print_expr(expr->as.index.object, indent + 2);
            print_indent(indent + 1);
            printf("Index:\n");
            ast_print_expr(expr->as.index.index, indent + 2);
            break;

        case EXPR_ARRAY:
            printf("Array(%zu elements)\n", expr->as.array.count);
            for(size_t i = 0; i < expr->as.array.count; i++) {
                ast_print_expr(expr->as.array.elements[i], indent + 1);
            }
            break;

        case EXPR_ASSIGN:
            printf("Assign(%s)\n", expr->as.assign.name);
            ast_print_expr(expr->as.assign.value, indent + 1);
            break;
    }
}

void ast_print_stmt(Stmt* stmt, int indent) {
    if(!stmt) {
        print_indent(indent);
        printf("<null>\n");
        return;
    }

    print_indent(indent);

    switch(stmt->type) {
        case STMT_EXPR:
            printf("ExprStmt\n");
            ast_print_expr(stmt->as.expr_stmt.expression, indent + 1);
            break;

        case STMT_VAR_DECL:
            printf("VarDecl(%s", stmt->as.var_decl.name);
            if(stmt->as.var_decl.type_annotation) {
                printf(": %s", stmt->as.var_decl.type_annotation);
            }
            printf(")\n");
            if(stmt->as.var_decl.initializer) {
                print_indent(indent + 1);
                printf("Initializer:\n");
                ast_print_expr(stmt->as.var_decl.initializer, indent + 2);
            }
            break;

        case STMT_FUNCTION_DECL:
            printf("FunctionDecl(%s)\n", stmt->as.function_decl.name);
            print_indent(indent + 1);
            printf("Params(%zu):\n", stmt->as.function_decl.param_count);
            for(size_t i = 0; i < stmt->as.function_decl.param_count; i++) {
                print_indent(indent + 2);
                printf("%s: %s\n", stmt->as.function_decl.param_names[i],
                       stmt->as.function_decl.param_types[i]);
            }
            if(stmt->as.function_decl.return_type) {
                print_indent(indent + 1);
                printf("Returns: %s\n", stmt->as.function_decl.return_type);
            }
            print_indent(indent + 1);
            printf("Body:\n");
            ast_print_stmt(stmt->as.function_decl.body, indent + 2);
            break;

        case STMT_IF:
            printf("IfStmt\n");
            print_indent(indent + 1);
            printf("Condition:\n");
            ast_print_expr(stmt->as.if_stmt.condition, indent + 2);
            print_indent(indent + 1);
            printf("Then:\n");
            ast_print_stmt(stmt->as.if_stmt.then_branch, indent + 2);
            if(stmt->as.if_stmt.else_branch) {
                print_indent(indent + 1);
                printf("Else:\n");
                ast_print_stmt(stmt->as.if_stmt.else_branch, indent + 2);
            }
            break;

        case STMT_WHILE:
            printf("WhileStmt\n");
            print_indent(indent + 1);
            printf("Condition:\n");
            ast_print_expr(stmt->as.while_stmt.condition, indent + 2);
            print_indent(indent + 1);
            printf("Body:\n");
            ast_print_stmt(stmt->as.while_stmt.body, indent + 2);
            break;

        case STMT_RETURN:
            printf("ReturnStmt\n");
            if(stmt->as.return_stmt.value) {
                ast_print_expr(stmt->as.return_stmt.value, indent + 1);
            }
            break;

        case STMT_BLOCK:
            printf("Block(%zu statements)\n", stmt->as.block.count);
            for(size_t i = 0; i < stmt->as.block.count; i++) {
                ast_print_stmt(stmt->as.block.statements[i], indent + 1);
            }
            break;
    }
}

void ast_print_node(ASTNode* node) {
    if(!node) {
        printf("<null>\n");
        return;
    }

    if(node->type == NODE_PROGRAM) {
        printf("Program(%zu statements)\n", node->as.program.count);
        for(size_t i = 0; i < node->as.program.count; i++) {
            ast_print_stmt(node->as.program.statements[i], 1);
        }
    }
}
